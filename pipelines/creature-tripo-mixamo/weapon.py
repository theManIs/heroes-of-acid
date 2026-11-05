"""Static separate weapon from its technical reference; resumable Tripo task.

Usage: .venv/bin/python pipelines/creature-tripo-mixamo/weapon.py hammerer
"""
import asyncio
import json
import sys
from tripo3d import TripoClient
from tripo3d.models import TaskStatus
from stage2 import ROOT, MODEL_VERSION, load_key, fetch


async def main(creature):
    out = ROOT / 'creatures' / creature / 'weapon'
    path = out / 'tripo_state.json'
    state = json.loads(path.read_text()) if path.exists() else {}
    async with TripoClient(api_key=load_key()) as client:
        if 'model' not in state:
            state['balance_before'] = (await client.get_balance()).balance
            state['model'] = {'task_id': await client.image_to_model(
                image=str(ROOT / 'references' / creature / 'hammer-reference.png'), model_version=MODEL_VERSION,
                face_limit=8000, texture_quality='detailed')}
            path.write_text(json.dumps(state, indent=2))
        task_id = state['model']['task_id']
        print('weapon', task_id, flush=True)
        task = await client.wait_for_task(task_id, verbose=False)
        state['model']['status'] = task.status.value
        path.write_text(json.dumps(state, indent=2))
        if task.status != TaskStatus.SUCCESS:
            raise RuntimeError(f'{task.status.value}: {task.error_msg}')
        await fetch(client, task_id, out, out / 'hammer.glb')
        state['balance_after'] = (await client.get_balance()).balance
        path.write_text(json.dumps(state, indent=2))
        print('Weapon saved', flush=True)


if __name__ == '__main__':
    asyncio.run(main(sys.argv[1]))
