#!/usr/bin/env python3
import re

pbxproj_path = "/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios/VirtualLibrary.xcodeproj/project.pbxproj"

with open(pbxproj_path, 'r') as f:
    content = f.read()

# Remove files from Products group
products_pattern = r'(7B2B3C4D5E6F7A8B9C0D1E3F /\* Products \*/ = \{[\s\S]*?children = \()([\s\S]*?)(3B2B3C4D5E6F7A8B9C0D1E3F /\* VirtualLibrary\.app \*/,)'
match = re.search(products_pattern, content)
if match:
    # Remove the authentication files from Products, keep only the .app file
    content = re.sub(
        products_pattern,
        r'\1\n\t\t\t\t\3',
        content
    )

# Add LoginView and LibrariesListView to Views group
views_pattern = r'(8B2B3C4D5E6F7A8B9C0D1E3F /\* Views \*/ = \{[\s\S]*?children = \([\s\S]*?)(5A2B3C4D5E6F7A8B9C0D1E3F /\* BookResultView\.swift \*/,)'
content = re.sub(
    views_pattern,
    r'\1\2\n\t\t\t\tD022A12D157A4F49B20F2DC7 /* LoginView.swift */,\n\t\t\t\t3DADE27A121746F885AA2B10 /* LibrariesListView.swift */,',
    content
)

# Add AuthenticationService to Services group
services_pattern = r'(1C2B3C4D5E6F7A8B9C0D1E3F /\* Services \*/ = \{[\s\S]*?children = \([\s\S]*?)(BE1E9ED82F2061F600B6EE93 /\* Library\.swift \*/,)'
content = re.sub(
    services_pattern,
    r'\1\2\n\t\t\t\t8B0951B47A2B405AB0E0ED13 /* AuthenticationService.swift */,',
    content
)

# Add LibrariesListViewModel to ViewModels group  
viewmodels_pattern = r'(0C2B3C4D5E6F7A8B9C0D1E3F /\* ViewModels \*/ = \{[\s\S]*?children = \([\s\S]*?)(8A2B3C4D5E6F7A8B9C0D1E3F /\* ScanCoverViewModel\.swift \*/,)'
content = re.sub(
    viewmodels_pattern,
    r'\1\2\n\t\t\t\t4BBAC38D7436436692BAA2E9 /* LibrariesListViewModel.swift */,',
    content
)

with open(pbxproj_path, 'w') as f:
    f.write(content)

print("✅ Fixed file group organization")
print("Files moved to correct groups:")
print("  - LoginView.swift → Views")
print("  - LibrariesListView.swift → Views")
print("  - AuthenticationService.swift → Services")
print("  - LibrariesListViewModel.swift → ViewModels")
