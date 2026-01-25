# Training a Custom Book Detection Model

## Why Train a Custom Model?

- **Better accuracy** on your specific book types (hardcovers, paperbacks, magazines)
- **Optimized for your use case** (library scanning vs. retail)
- **Smaller model size** (only learns book detection, not general objects)
- **Faster inference** (specialized models can be more efficient)

## Prerequisites

```bash
# Install required tools
pip install coremltools
pip install tensorflow  # or pytorch
pip install pillow
pip install numpy
```

## Option 1: Using Create ML (Easiest - No Code)

Apple's Create ML app makes training models simple.

### Step 1: Prepare Your Dataset

Create this folder structure:
```
BookTrainingData/
├── Training/
│   ├── Books/
│   │   ├── book_001.jpg
│   │   ├── book_002.jpg
│   │   └── ...
│   └── NotBooks/
│       ├── background_001.jpg
│       ├── table_001.jpg
│       └── ...
├── Validation/
│   ├── Books/
│   └── NotBooks/
└── Testing/
    ├── Books/
    └── NotBooks/
```

**Data Requirements:**
- **Minimum:** 100 images per class
- **Good:** 500 images per class
- **Excellent:** 2000+ images per class

### Step 2: Open Create ML

1. Open Xcode
2. Go to **Xcode > Open Developer Tool > Create ML**
3. Click **New Document**
4. Choose **Image Classifier**

### Step 3: Configure Training

```
Training Data: Select Training folder
Validation Data: Select Validation folder
Testing Data: Select Testing folder

Augmentations:
☑ Flip
☑ Rotate
☑ Blur
☑ Expose
☑ Noise
☑ Crop

Iterations: 25 (increase for better accuracy)
Algorithm: Transfer Learning (recommended)
```

### Step 4: Train

1. Click **Train**
2. Wait 10-30 minutes (depends on dataset size)
3. Review accuracy metrics:
   - **Training Accuracy:** Should be > 95%
   - **Validation Accuracy:** Should be > 90%

### Step 5: Export

1. Click **Output** tab
2. See model performance
3. Click **Get** to save `.mlmodel` file
4. Drag into Xcode project

## Option 2: Object Detection with Create ML

For detecting book positions (bounding boxes):

### Step 1: Prepare Annotated Data

Use an annotation tool like [Roboflow](https://roboflow.com) or [LabelImg](https://github.com/tzutalin/labelImg).

Create annotations in JSON format:
```json
{
  "images": [
    {
      "id": 1,
      "file_name": "book_001.jpg",
      "width": 1920,
      "height": 1080
    }
  ],
  "annotations": [
    {
      "id": 1,
      "image_id": 1,
      "category_id": 1,
      "bbox": [100, 200, 300, 450],
      "area": 135000
    }
  ],
  "categories": [
    {
      "id": 1,
      "name": "book"
    }
  ]
}
```

### Step 2: Create ML Object Detection

```
1. New Document > Object Detector
2. Add your annotated dataset
3. Configure:
   - Max Iterations: 10000
   - Algorithm: YOLOv3 or Faster R-CNN
4. Train
5. Export .mlmodel
```

## Option 3: Using Python & Core ML Tools (Most Flexible)

### Full Training Pipeline

```python
#!/usr/bin/env python3
"""
Train a custom book detection model and convert to Core ML
"""

import tensorflow as tf
from tensorflow import keras
import coremltools as ct
import os
import numpy as np
from PIL import Image

# ============================================
# 1. Prepare Dataset
# ============================================

def load_dataset(data_dir, img_size=(224, 224)):
    """Load and preprocess images"""
    
    train_ds = keras.preprocessing.image_dataset_from_directory(
        f"{data_dir}/Training",
        image_size=img_size,
        batch_size=32,
        label_mode='categorical'
    )
    
    val_ds = keras.preprocessing.image_dataset_from_directory(
        f"{data_dir}/Validation",
        image_size=img_size,
        batch_size=32,
        label_mode='categorical'
    )
    
    # Normalize pixel values
    normalization_layer = keras.layers.Rescaling(1./255)
    train_ds = train_ds.map(lambda x, y: (normalization_layer(x), y))
    val_ds = val_ds.map(lambda x, y: (normalization_layer(x), y))
    
    # Optimize performance
    train_ds = train_ds.cache().prefetch(buffer_size=tf.data.AUTOTUNE)
    val_ds = val_ds.cache().prefetch(buffer_size=tf.data.AUTOTUNE)
    
    return train_ds, val_ds

# ============================================
# 2. Build Model (Transfer Learning)
# ============================================

def create_book_classifier(num_classes=2):
    """Create model using transfer learning from MobileNetV3"""
    
    # Load pre-trained MobileNetV3 (without top layer)
    base_model = keras.applications.MobileNetV3Small(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )
    
    # Freeze base model layers (transfer learning)
    base_model.trainable = False
    
    # Add custom classification head
    model = keras.Sequential([
        base_model,
        keras.layers.GlobalAveragePooling2D(),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dropout(0.5),
        keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    return model

# ============================================
# 3. Train Model
# ============================================

def train_model(model, train_ds, val_ds, epochs=25):
    """Train the model with data augmentation"""
    
    # Compile model
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Callbacks
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_accuracy',
            patience=5,
            restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.2,
            patience=3
        ),
        keras.callbacks.ModelCheckpoint(
            'best_model.h5',
            monitor='val_accuracy',
            save_best_only=True
        )
    ]
    
    # Train
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        callbacks=callbacks
    )
    
    return history

# ============================================
# 4. Convert to Core ML
# ============================================

def convert_to_coreml(model, class_labels):
    """Convert Keras model to Core ML format"""
    
    # Define input shape
    image_input = ct.ImageType(
        name="image",
        shape=(1, 224, 224, 3),
        scale=1/255.0
    )
    
    # Convert
    coreml_model = ct.convert(
        model,
        inputs=[image_input],
        classifier_config=ct.ClassifierConfig(class_labels)
    )
    
    # Set metadata
    coreml_model.author = "Your Name"
    coreml_model.short_description = "Book detection classifier"
    coreml_model.version = "1.0"
    
    # Set input/output descriptions
    coreml_model.input_description["image"] = "Input image of potential book"
    coreml_model.output_description["classLabel"] = "Most likely class"
    coreml_model.output_description["classLabelProbs"] = "Probability of each class"
    
    return coreml_model

# ============================================
# 5. Main Training Pipeline
# ============================================

def main():
    print("🚀 Starting book detection model training...")
    
    # Configuration
    DATA_DIR = "./BookTrainingData"
    CLASS_LABELS = ["NotBook", "Book"]
    EPOCHS = 25
    
    # Load data
    print("📊 Loading dataset...")
    train_ds, val_ds = load_dataset(DATA_DIR)
    
    # Create model
    print("🏗️ Creating model...")
    model = create_book_classifier(num_classes=len(CLASS_LABELS))
    model.summary()
    
    # Train
    print("🎓 Training model...")
    history = train_model(model, train_ds, val_ds, epochs=EPOCHS)
    
    # Evaluate
    print("📈 Final validation accuracy:", max(history.history['val_accuracy']))
    
    # Convert to Core ML
    print("📱 Converting to Core ML...")
    coreml_model = convert_to_coreml(model, CLASS_LABELS)
    
    # Save
    output_path = "BookDetector.mlmodel"
    coreml_model.save(output_path)
    print(f"✅ Model saved to {output_path}")
    
    # Display recommendations
    val_acc = max(history.history['val_accuracy'])
    if val_acc < 0.85:
        print("⚠️ Validation accuracy is low. Consider:")
        print("   - Collecting more training data")
        print("   - Training for more epochs")
        print("   - Adjusting data augmentation")
    elif val_acc < 0.95:
        print("✓ Good accuracy. Can be improved with more data.")
    else:
        print("✅ Excellent accuracy! Model is ready for deployment.")

if __name__ == "__main__":
    main()
```

### Run Training

```bash
# Install dependencies
pip install -r requirements.txt

# Run training
python train_book_detector.py

# This will create: BookDetector.mlmodel
```

## Option 4: Using Turi Create (Apple's Framework)

```python
import turicreate as tc

# Load images
data = tc.image_analysis.load_images('./BookTrainingData/Training', with_path=True)

# Label data based on folder structure
data['label'] = data['path'].apply(lambda path: 'book' if '/Books/' in path else 'not_book')

# Create model
model = tc.image_classifier.create(
    data,
    target='label',
    model='resnet-50',
    max_iterations=25
)

# Evaluate
metrics = model.evaluate(test_data)
print(metrics)

# Export to Core ML
model.export_coreml('BookClassifier.mlmodel')
```

## Collecting Training Data

### Quick Data Collection App

Add to your iOS app for easy data collection:

```swift
class DataCollectionService {
    func saveTrainingImage(_ image: UIImage, isBook: Bool) {
        let folder = isBook ? "Books" : "NotBooks"
        let filename = "img_\(Date().timeIntervalSince1970).jpg"
        
        // Save to Files app
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        let folderURL = documentsPath.appendingPathComponent("TrainingData/\(folder)")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let fileURL = folderURL.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        
        print("✅ Saved training image: \(filename)")
    }
}

// Use in your scan view
Button("Save as Training Data") {
    dataCollectionService.saveTrainingImage(capturedImage, isBook: true)
}
```

### Data Augmentation Tips

```python
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# Augmentation configuration
datagen = ImageDataGenerator(
    rotation_range=20,           # Rotate images
    width_shift_range=0.2,       # Shift horizontally
    height_shift_range=0.2,      # Shift vertically
    shear_range=0.2,            # Shear transformations
    zoom_range=0.2,             # Zoom in/out
    horizontal_flip=True,        # Flip horizontally
    brightness_range=[0.8, 1.2], # Adjust brightness
    fill_mode='nearest'          # Fill strategy
)

# This multiplies your dataset by ~10x
```

## Model Optimization

### Quantization (Reduce Size)

```python
# During conversion to Core ML
coreml_model = ct.convert(
    model,
    inputs=[image_input],
    compute_precision=ct.precision.FLOAT16  # Reduce from 32-bit to 16-bit
)

# Further quantization
quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
    coreml_model,
    nbits=8  # 8-bit quantization
)
```

### Pruning (Faster Inference)

```python
import tensorflow_model_optimization as tfmot

# Apply pruning during training
pruning_schedule = tfmot.sparsity.keras.PolynomialDecay(
    initial_sparsity=0.0,
    final_sparsity=0.5,
    begin_step=0,
    end_step=1000
)

model = tfmot.sparsity.keras.prune_low_magnitude(
    model,
    pruning_schedule=pruning_schedule
)
```

## Benchmarking Your Model

```swift
import CoreML

func benchmarkModel() {
    let model = try! BookDetector(configuration: MLModelConfiguration())
    
    let iterations = 100
    var totalTime: TimeInterval = 0
    
    for _ in 0..<iterations {
        let start = Date()
        let _ = try! model.prediction(image: testImage)
        totalTime += Date().timeIntervalSince(start)
    }
    
    let avgTime = totalTime / Double(iterations)
    print("⏱️ Average inference time: \(avgTime * 1000)ms")
    print("📊 FPS: \(1.0 / avgTime)")
    
    // Target: < 50ms per inference (20+ FPS)
}
```

## Troubleshooting

### Low Accuracy
- Collect more diverse training data
- Increase training epochs
- Try different base models (ResNet50, EfficientNet)
- Verify data labels are correct

### Overfitting
- Add more dropout layers
- Increase data augmentation
- Collect more training data
- Reduce model complexity

### Slow Inference
- Use smaller base model (MobileNetV3-Small)
- Apply quantization
- Reduce input image size
- Use GPU acceleration

## Resources

- [Create ML Documentation](https://developer.apple.com/documentation/createml)
- [Core ML Tools](https://coremltools.readme.io/)
- [TensorFlow Model Optimization](https://www.tensorflow.org/model_optimization)
- [Turi Create](https://apple.github.io/turicreate/docs/userguide/)
- [Roboflow (Annotation)](https://roboflow.com)

## Next Steps

1. Collect 200+ book images from your library
2. Train using Create ML (easiest)
3. Test in your app
4. If accuracy is good (>90%), ship it!
5. If not, collect more data and retrain
