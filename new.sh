#for nvidia/cuda:12.1.0-runtime-ubuntu22.04

bash -c '
set -e

cd /notebooks

echo "=== Installing system deps ==="
apt-get update -y
apt-get install -y git python3-venv python3-pip

echo "=== Cloning Forge ==="
if [ ! -d stable-diffusion-webui-forge ]; then
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git
fi

cd stable-diffusion-webui-forge

echo "=== Creating venv ==="
if [ ! -d venv ]; then
    python3 -m venv venv
fi

source venv/bin/activate

echo "=== Upgrading pip ==="
pip install --upgrade pip setuptools wheel

echo "=== Removing any accidental torch ==="
pip uninstall -y torch torchvision torchaudio || true

echo "=== Installing CUDA-compatible Torch (stable choice) ==="
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

echo "=== Installing Forge requirements ==="
pip install -r requirements.txt || true

echo "=== Fallback deps (if needed) ==="
pip install xformers==0.0.23 safetensors accelerate transformers || true

echo "=== Launching Forge ==="
python launch.py --xformers --skip-torch-cuda-test --listen --port 7860
'
