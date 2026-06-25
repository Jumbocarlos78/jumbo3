#!/bin/bash
# =============================================================================
# ComfyUI — Paperspace Gradient Notebook Startup Script
# Base image: paperspace/gradient-base:pt211-tf215-cudatk120-py311-20240202
# =============================================================================
# WHAT THIS DOES:
#   - Starts JupyterLab immediately (Gradient's interface stays responsive)
#   - Installs ComfyUI + nodes + Wan 2.2 I2V models in the background
#   - Symlinks /storage/output so generated videos/images persist
#   - Everything else (ComfyUI install, models) is ephemeral — gone on restart
#
# SETUP:
#   1. Put this file in a GitHub repo
#   2. Gradient Notebook settings:
#        Container Name : paperspace/gradient-base:pt211-tf215-cudatk120-py311-20240202
#        Workspace URL  : https://github.com/YOUR_USER/YOUR_REPO.git
#        Command        : bash /notebooks/startup-paperspace.sh
#
# EACH SESSION:
#   - Watch setup progress: tail -f /tmp/comfyui-setup.log (from JupyterLab terminal)
#   - ComfyUI available at: https://<notebook-id>-8888.paperspacegradient.com
#     (only after setup completes — ~20-30 min first run)
#   - Upload your SDXL checkpoints via JupyterLab file browser to:
#       /opt/ComfyUI/models/checkpoints/
#
# WAN 2.2 FILENAMES:
#   Verify against https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged
#   before first run — they are flagged in the download section below.
# =============================================================================

COMFYUI_DIR="/opt/ComfyUI"
STORAGE="/storage"
LOG="/tmp/comfyui-setup.log"

# --- BACKGROUND SETUP --------------------------------------------------------
# Runs concurrently with JupyterLab so Gradient's interface is immediately usable.
# Monitor progress from a JupyterLab terminal: tail -f /tmp/comfyui-setup.log

setup_comfyui() {
    exec > "$LOG" 2>&1   # All output from this function goes to the log file

    echo "============================================================"
    echo " ComfyUI Setup — $(date)"
    echo " Progress: tail -f $LOG"
    echo "============================================================"
    echo ""

    # -- [1/5] System dependencies --
    echo "[1/5] Installing system dependencies..."
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        git \
        ffmpeg \
        libgl1 \
        libglib2.0-0
    echo "  ✓ Done"
    echo ""

    # -- [2/5] ComfyUI --
    echo "[2/5] Installing ComfyUI..."
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    # Base image has PyTorch pre-installed with CUDA — requirements.txt will
    # skip torch if the existing version satisfies the constraint
    pip install -q -r "$COMFYUI_DIR/requirements.txt"
    echo "  ✓ Done"
    echo ""

    # -- [3/5] Custom nodes --
    echo "[3/5] Installing custom nodes..."
    cd "$COMFYUI_DIR/custom_nodes"

    # ComfyUI-Manager: in-UI node installer/updater
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager
    pip install -q -r ComfyUI-Manager/requirements.txt
    echo "  ✓ ComfyUI-Manager"

    # VideoHelperSuite: stitches ComfyUI's output frames into a video file
    # Required — without this you get individual frames, not a video
    git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
    pip install -q -r ComfyUI-VideoHelperSuite/requirements.txt
    echo "  ✓ VideoHelperSuite"
    echo ""

    # -- [4/5] Download Wan 2.2 I2V models --
    echo "[4/5] Downloading Wan 2.2 I2V models (~25 GB — this takes a while)..."
    pip install -q "huggingface_hub[cli]"
    export HF_XET_HIGH_PERFORMANCE=1   # Faster Xet-protocol transfers

    WAN_REPO="Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
    MODELS="$COMFYUI_DIR/models"
    mkdir -p "$MODELS/"{diffusion_models,vae,text_encoders,clip_vision,checkpoints,loras}

    # Helper: download a single file, log success or failure
    dl() {
        local repo="$1" file="$2" dest="$3"
        echo "  ⏬ $file"
        if huggingface-cli download "$repo" "$file" --local-dir "$dest"; then
            echo "  ✓ $file"
        else
            echo "  ✗ FAILED: $file"
            echo "    → Verify filename at: https://huggingface.co/$repo"
        fi
        echo ""
    }

    # VERIFY THESE FILENAMES before first run — see header note above
    dl "$WAN_REPO" "wan2.2_i2v_480p_14B_fp8_scaled.safetensors" "$MODELS/diffusion_models"
    dl "$WAN_REPO" "wan_2.1_vae.safetensors"                     "$MODELS/vae"
    dl "$WAN_REPO" "umt5_xxl_fp8_e4m3fn_scaled.safetensors"      "$MODELS/text_encoders"
    dl "$WAN_REPO" "clip_vision_h.safetensors"                    "$MODELS/clip_vision"

    echo "  ✓ All downloads attempted"
    echo ""

    # -- [5/5] Output persistence --
    echo "[5/5] Wiring output to persistent storage..."
    mkdir -p "$STORAGE/output"
    rm -rf "$COMFYUI_DIR/output"
    ln -sfn "$STORAGE/output" "$COMFYUI_DIR/output"
    echo "  ✓ $COMFYUI_DIR/output → $STORAGE/output"
    echo ""

    # -- Start ComfyUI --
    echo "============================================================"
    echo " Starting ComfyUI on port 8888..."
    echo " Access at: https://<notebook-id>-8888.paperspacegradient.com"
    echo ""
    echo " Upload your SDXL checkpoints via JupyterLab file browser to:"
    echo "   $MODELS/checkpoints/"
    echo "============================================================"

    cd "$COMFYUI_DIR"
    python3 main.py --listen 0.0.0.0 --port 8888
    # Note: no & here — ComfyUI keeps this background function alive
    # If ComfyUI exits, the function ends and the log reflects it
}

# Kick off setup in the background
setup_comfyui &
SETUP_PID=$!
echo "Setup running in background (PID $SETUP_PID)"
echo "  → Monitor progress: tail -f $LOG"
echo "  → ComfyUI will be available once setup completes (~20-30 min)"
echo ""

# --- JUPYTERLAB (foreground — keeps Gradient's interface alive) --------------
exec PIP_DISABLE_PIP_VERSION_CHECK=1
    exec jupyter lab \
    --allow-root \
    --ip=0.0.0.0 \
    --no-browser \
    --ServerApp.trust_xheaders=True \
    --ServerApp.disable_check_xsrf=False \
    --ServerApp.allow_remote_access=True \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_credentials=True
