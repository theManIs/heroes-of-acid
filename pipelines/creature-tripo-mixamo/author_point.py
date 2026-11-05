"""Author a compact two-handed thrust from the retargeted Mixamo idle pose.

Feet and pelvis retain idle. Analytic arm IK keeps both palms on the rigid shaft;
the torso stays facing the target, without the sword clip's wide turning windup.
"""
import math
from build_clips import (read_glb, accessor, Skeleton, qmul, qinv, qrot,
                         qbetween, qnorm, write, unit)

P = 'mixamorig:'


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, value):
    return tuple(x * value for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def length(a):
    return math.sqrt(dot(a, a))


def point(skeleton, pose, name):
    return skeleton.world(skeleton.by_name[P + name], pose)[1]


def rotation(skeleton, pose, name):
    return skeleton.world(skeleton.by_name[P + name], pose)[0]


def set_world_rotation(skeleton, pose, name, world):
    index = skeleton.by_name[P + name]
    parent = skeleton.parent.get(index)
    parent_rotation = skeleton.world(parent, pose)[0] if parent is not None else (0, 0, 0, 1)
    pose.setdefault(index, {})['r'] = qnorm(qmul(qinv(parent_rotation), world))


def solve_arm(skeleton, pose, side, wrist, hand_rotation):
    arm, fore, hand = [side + suffix for suffix in ('Arm', 'ForeArm', 'Hand')]
    shoulder, elbow, old_wrist = [point(skeleton, pose, name) for name in (arm, fore, hand)]
    first, second = length(sub(elbow, shoulder)), length(sub(old_wrist, elbow))
    direction = unit(sub(wrist, shoulder))
    distance = min(length(sub(wrist, shoulder)), (first + second) * .999)
    wrist = add(shoulder, mul(direction, distance))
    along = (first * first - second * second + distance * distance) / (2 * distance)
    height = math.sqrt(max(0, first * first - along * along))
    old_bend = sub(elbow, shoulder)
    pole = sub(old_bend, mul(direction, dot(old_bend, direction)))
    if length(pole) < .0001:
        pole = (0, -1, 0)
    desired_elbow = add(add(shoulder, mul(direction, along)), mul(unit(pole), height))
    delta = qbetween(sub(elbow, shoulder), sub(desired_elbow, shoulder))
    set_world_rotation(skeleton, pose, arm, qmul(delta, rotation(skeleton, pose, arm)))
    elbow, old_wrist = [point(skeleton, pose, name) for name in (fore, hand)]
    delta = qbetween(sub(old_wrist, elbow), sub(wrist, elbow))
    set_world_rotation(skeleton, pose, fore, qmul(delta, rotation(skeleton, pose, fore)))
    set_world_rotation(skeleton, pose, hand, hand_rotation)


def author(rig_path, idle_path, target, duration=1.1):
    doc, binary = read_glb(idle_path)
    skeleton = Skeleton(doc)
    skeleton.path = rig_path
    base = {}
    for channel in doc['animations'][0]['channels']:
        sampler = doc['animations'][0]['samplers'][channel['sampler']]
        base.setdefault(channel['target']['node'], {})[channel['target']['path'][0]] = accessor(doc, binary, sampler['output'])[0]
    palms, offsets, hands = {}, {}, {}
    for side in ('Right', 'Left'):
        hand = point(skeleton, base, side + 'Hand')
        palm = add(hand, mul(sub(point(skeleton, base, side + 'HandMiddle1'), hand), .75))
        palms[side] = palm
        offsets[side] = sub(palm, hand)
        hands[side] = rotation(skeleton, base, side + 'Hand')
    grip_axis = unit(sub(palms['Right'], palms['Left']))
    grip_distance = length(sub(palms['Right'], palms['Left']))
    forward, _ = skeleton.frame()
    # Controlled forward head contact, with the shaft almost horizontal at impact.
    strike_axis = unit(add(forward, (0, -.08, 0)))
    keys = [(0, 0, 0), (.22, -.035, .08), (.48, .075, 1), (.61, .065, .9), (1, 0, 0)]
    count = round(duration * 30) + 1
    times = [duration * i / (count - 1) for i in range(count)]
    rotations = {bone: [] for bone in skeleton.bones}
    hips = []
    for time in times:
        t = time / duration
        segment = next((i for i in range(len(keys) - 1) if t <= keys[i + 1][0]), len(keys) - 2)
        a, b = keys[segment:segment + 2]
        blend = (t - a[0]) / (b[0] - a[0])
        blend = blend * blend * (3 - 2 * blend)
        push = a[1] + (b[1] - a[1]) * blend
        amount = a[2] + (b[2] - a[2]) * blend
        axis = unit(add(mul(grip_axis, 1 - amount), mul(strike_axis, amount)))
        turn = qbetween(grip_axis, axis)
        right = add(palms['Right'], add(mul(forward, push), (0, .035 * amount, 0)))
        left = sub(right, mul(axis, grip_distance))
        pose = {index: dict(value) for index, value in base.items()}
        for side, palm in [('Right', right), ('Left', left)]:
            wrist = sub(palm, qrot(turn, offsets[side]))
            solve_arm(skeleton, pose, side, wrist, qmul(turn, hands[side]))
        for bone in skeleton.bones:
            rotations[bone].append(skeleton.local(skeleton.by_name[bone], pose)[0])
        hips.append(skeleton.local(skeleton.by_name[P + 'Hips'], pose)[1])
    rig_doc, _ = read_glb(rig_path)
    write(rig_doc, skeleton, 'attack_point', times, rotations, hips, target)
    print('attack_point: authored two-handed thrust', duration, 's')
