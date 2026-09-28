i_pwd=$(pwd)
cd ~/.local/share/piper-voices

for v in thorsten/medium/de_DE-thorsten-medium eva_k/x_low/de_DE-eva_k-x_low \
         pavoque/low/de_DE-pavoque-low; do
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/$v.onnx"
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/$v.onnx.json"
done

for v in gilles/low/fr_FR-gilles-low siwis/medium/fr_FR-siwis-medium \
         tom/medium/fr_FR-tom-medium; do
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/$v.onnx"
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/$v.onnx.json"
done

for v in hfc_male/medium/en_US-hfc_male-medium joe/medium/en_US-joe-medium \
         hfc_female/medium/en_US-hfc_female-medium; do
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/$v.onnx"
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/$v.onnx.json"
done

cd $i_pwd