cd /notebooks

apt-get update -y
apt-get install -y git python3-venv python3-pip

git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git

cd stable-diffusion-webui-forge

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip

pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

pip install -r requirements.txt
