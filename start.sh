cd /notebooks/stable-diffusion-webui-forge
source venv/bin/activate

exec python launch.py --listen --port 7860 --xformers --skip-torch-cuda-test
