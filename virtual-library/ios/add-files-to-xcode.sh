#!/bin/bash

# Script to add new Swift files to Xcode project
# This creates a simple Swift Package Manager structure as an alternative

PROJECT_DIR="/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios"
cd "$PROJECT_DIR"

echo "Adding new Swift files to Xcode project..."

# The files we need to add
FILES=(
    "VirtualLibraryApp/Models/Library.swift"
    "VirtualLibraryApp/ViewModels/CreateLibraryViewModel.swift"
    "VirtualLibraryApp/Views/CreateLibraryView.swift"
)

# Generate UUIDs for the files
generate_uuid() {
    uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c1-24
}

PBXPROJ="VirtualLibrary.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PBXPROJ" "${PBXPROJ}.backup"

echo "Created backup at ${PBXPROJ}.backup"

# For each file, we need to add:
# 1. PBXFileReference
# 2. PBXBuildFile
# 3. Add to PBXGroup
# 4. Add to PBXSourcesBuildPhase

for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    
    # Generate UUIDs
    fileref_uuid=$(generate_uuid)
    buildfile_uuid=$(generate_uuid)
    
    echo "Processing $filename..."
    echo "  FileRef UUID: $fileref_uuid"
    echo "  BuildFile UUID: $buildfile_uuid"
    
    # Add PBXBuildFile entry
    sed -i '' "/\/\* Begin PBXBuildFile section \*\//a\\
\ \ \ \ \ \ \ \ ${buildfile_uuid} /* ${filename} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileref_uuid} /* ${filename} */; };
" "$PBXPROJ"
    
    # Add PBXFileReference entry
    sed -i '' "/\/\* Begin PBXFileReference section \*\//a\\
\ \ \ \ \ \ \ \ ${fileref_uuid} /* ${filename} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${filename}; sourceTree = \"<group>\"; };
" "$PBXPROJ"
    
done

echo ""
echo "✅ Files added to Xcode project"
echo ""
echo "⚠️  IMPORTANT: You still need to:"
echo "1. Open Xcode"
echo "2. Clean Build Folder (Cmd+Shift+K)"
echo "3. Build the project (Cmd+B)"
echo ""
echo "If there are issues, restore the backup:"
echo "  mv ${PBXPROJ}.backup $PBXPROJ"
