
import streamlit as st
import numpy as np
import torch
from PIL import Image, UnidentifiedImageError
from transformers import AutoModel

# -------------------------------
# 1. Page configuration
# -------------------------------
st.set_page_config(
    page_title="Medical AI Image Analyzer",
    page_icon="🩺",
    layout="centered"
)

st.title("Medical AI Image Analyzer")
st.write(
    "An educational AI prototype for analyzing "
    "frontal chest X-ray images."
)

st.warning(
    "Educational demonstration only. This application "
    "cannot diagnose a patient or replace a doctor. "
    "Do not use its output for medical decisions."
)

# -------------------------------
# 2. Load the pretrained AI model
# -------------------------------
@st.cache_resource(show_spinner="Loading AI model...")
def load_model():
    model = AutoModel.from_pretrained(
        "ianpan/pneumonia-cxr",
        trust_remote_code=True
    )
    model.eval()
    return model

# -------------------------------
# 3. Upload an image
# -------------------------------
uploaded_file = st.file_uploader(
    "Upload a frontal chest X-ray",
    type=["jpg", "jpeg", "png"]
)

if uploaded_file is not None:
    try:
        image = Image.open(uploaded_file).convert("RGB")

        st.subheader("Uploaded X-ray")
        st.image(image, caption="Uploaded image",
                 width="stretch")

        # -------------------------------
        # 4. Run AI prediction
        # -------------------------------
        if st.button("Analyze Image", type="primary"):
            with st.spinner("AI is analyzing the image..."):
                model = load_model()
                grayscale_image = np.array(image.convert("L"))
                pixel_values = torch.from_numpy(
                    model.preprocess(grayscale_image).copy()
                ).unsqueeze(0).unsqueeze(0)
                with torch.inference_mode():
                    results = model(pixel_values)

            st.subheader("Model Output")
            if (
                not isinstance(results, dict)
                or not torch.is_tensor(results.get("cls"))
                or results["cls"].numel() != 1
            ):
                st.error(
                    "The model returned an unexpected result. "
                    "Please check the model setup."
                )
            else:
                score = float(results["cls"].item())
                category = (
                    "Pneumonia-like opacity"
                    if score >= 0.5
                    else "No pneumonia-like opacity detected"
                )
                st.write(f"**Predicted category:** {category}")
                st.write(f"**Model score:** {score * 100:.2f}%")
                st.progress(max(0.0, min(1.0, score)))

                st.info(
                    "This is a model prediction, not a confirmed "
                    "disease diagnosis. A qualified medical "
                    "professional must interpret the X-ray."
                )

    except (UnidentifiedImageError, OSError):
        st.error("Unable to read this image. Please upload a valid image.")

    except Exception as error:
        st.error(
            "The model could not analyze the image. "
            "Check your internet connection and installed "
            "libraries, then try again."
        )
        st.caption(f"Technical details: {error}")
else:
    st.info("Upload a chest X-ray to begin.")
