#!/bin/bash

# Script to add authentication files to Xcode project

PROJECT_DIR="/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios"
cd "$PROJECT_DIR"

echo "Adding authentication files to Xcode project..."

# The new files
FILES=(
    "VirtualLibraryApp/Services/AuthenticationService.swift"
    "VirtualLibraryApp/Views/LoginView.swift"
    "VirtualLibraryApp/Views/LibrariesListView.swift"
    "VirtualLibraryApp/ViewModels/LibrariesListViewModel.swift"
)

# Generate UUIDs
generate_uuid() {
    uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c1-24
}

PBXPROJ="VirtualLibrary.xcodeproj/project.pbxproj"

# Backup
cp "$PBXPROJ" "${PBXPROJ}.backup-auth"
echo "Created backup at ${PBXPROJ}.backup-auth"

for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    
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
echo "⚠️  IMPORTANT: In Xcode, you need to:"
echo "1. Go to Signing & Capabilities tab"
echo "2. Click '+ Capability'"
echo "3. Add 'Sign in with Apple'"
echo "4. Clean Build Folder (Cmd+Shift+K)"
echo "5. Build the project (Cmd+B)"
echo ""
echo "If there are issues, restore the backup:"
echo "  mv ${PBXPROJ}.backup-auth $PBXPROJ"
