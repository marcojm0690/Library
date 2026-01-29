#!/bin/bash

# Add Quote.swift, QuoteVerificationViewModel.swift, QuoteVerificationView.swift, and QuoteResultView.swift to Xcode project

cd "$(dirname "$0")"

echo "Please add the following files to your Xcode project manually:"
echo ""
echo "1. VirtualLibraryApp/Models/Quote.swift"
echo "2. VirtualLibraryApp/ViewModels/QuoteVerificationViewModel.swift"
echo "3. VirtualLibraryApp/Views/QuoteVerificationView.swift"
echo "4. VirtualLibraryApp/Views/QuoteResultView.swift"
echo ""
echo "Steps:"
echo "1. Open VirtualLibrary.xcworkspace in Xcode"
echo "2. Right-click on the Models folder → Add Files to \"VirtualLibrary\"..."
echo "3. Navigate to VirtualLibraryApp/Models and select Quote.swift"
echo "4. Ensure \"Copy items if needed\" is UNCHECKED"
echo "5. Ensure \"Create groups\" is selected"
echo "6. Ensure \"VirtualLibrary\" target is checked"
echo "7. Click Add"
echo "8. Repeat for the ViewModels and Views folders"
echo ""
echo "Or run: open VirtualLibrary.xcworkspace"
