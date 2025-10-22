# TestFlight Submission Checklist

## ✅ Pre-Submission Tasks

### 1. **Code Cleanup**
- [x] Remove debug logging from production code
- [ ] Remove any TODO comments that aren't needed
- [ ] Remove unused imports
- [ ] Check for commented-out code

### 2. **Affiliate Configuration**
- [ ] Sign up for TCGPlayer Affiliate Program (Commission Junction)
- [ ] Sign up for eBay Partner Network
- [ ] Get eBay Developer App ID
- [ ] Update `AffiliateService.swift` line 18-19 with your affiliate IDs:
  ```swift
  private let tcgPlayerAffiliateID = "YOUR_TCGPLAYER_AFFILIATE_ID"
  private let ebayPartnerNetworkCampaignID = "YOUR_EBAY_CAMPAIGN_ID"
  ```
- [ ] Update `PricingService.swift` line 268 with your eBay App ID:
  ```swift
  let ebayAppID = "YOUR_EBAY_APP_ID"
  ```
- [ ] Add affiliate disclosure to app (already done - in BuyCardSheet.swift)

### 3. **App Store Configuration**

#### App Information
- **App Name**: Inkwell Keeper
- **Subtitle**: Lorcana Collection Manager
- **Category**: Utilities or Entertainment
- **Content Rating**: 4+

#### What to Include in Description:
```
Track your Disney Lorcana TCG collection with ease!

FEATURES:
• Scan cards using your camera with OCR technology
• Track your complete collection with variants
• Build competitive decks with format validation
• Wishlist cards you're hunting for
• View estimated card values
• Browse all Lorcana sets
• Comprehensive statistics

DECK BUILDING:
• Support for Core Constructed and Infinity formats
• Visual cost curve and deck statistics
• Track collection completion per deck
• See estimated cost to complete decks
• Filter by owned cards when building

AFFILIATE DISCLOSURE:
Purchase links help support app development through affiliate commissions.
```

#### Screenshots Needed:
1. Collection view (showing cards grid)
2. Scanner in action
3. Card detail view
4. Deck builder interface
5. Deck statistics view
6. Sets view

### 4. **Privacy & Compliance**

#### Privacy Policy Requirements:
- [ ] Create privacy policy (required for App Store)
- [ ] Host privacy policy URL
- [ ] Add privacy policy link to app settings

**Key Points to Include:**
- App stores data locally on device (SwiftData)
- No personal information collected
- Camera used only for card scanning (not stored)
- Affiliate links disclosed
- Third-party services: TCGPlayer, eBay (for pricing/links)

#### App Tracking Transparency:
- Currently NO tracking implemented
- No need for ATT prompt unless you add analytics

### 5. **Build Settings**

#### Version & Build Numbers:
- [ ] Set Marketing Version (e.g., "1.0")
- [ ] Set Build Number (e.g., "1")
- [ ] Increment for each TestFlight upload

#### Bundle Identifier:
- [ ] Verify bundle ID matches App Store Connect
- [ ] Example: `com.yourname.inkwell-keeper`

#### Signing:
- [ ] Ensure automatic signing is enabled OR
- [ ] Set up manual provisioning profiles
- [ ] Distribution certificate installed

#### Deployment Target:
- [ ] Check minimum iOS version (currently iOS 17+)
- [ ] Consider lowering if needed for wider audience

### 6. **Testing Before Upload**

#### Critical User Flows:
- [ ] Add a card manually
- [ ] Scan a card with camera
- [ ] Add card to wishlist
- [ ] Remove card from collection
- [ ] Create a deck
- [ ] Add cards to deck (owned and unowned)
- [ ] View deck statistics
- [ ] Check deck validation
- [ ] Export deck list
- [ ] Browse sets view
- [ ] Filter collection
- [ ] View stats

#### Edge Cases:
- [ ] App works without any cards added
- [ ] Scanner handles card not found
- [ ] Deck builder handles no owned cards
- [ ] Prices show estimates when API unavailable

### 7. **App Store Connect Setup**

- [ ] Create app in App Store Connect
- [ ] Upload app icon (1024x1024)
- [ ] Fill out App Information
- [ ] Set pricing (Free recommended)
- [ ] Configure TestFlight
- [ ] Add internal testers
- [ ] Add external testers (if needed)

### 8. **Known Limitations to Document**

**For Beta Testers:**
- Prices are estimates (no official TCGPlayer API access)
- Card data loaded from local JSON files
- Images loaded from Lorcana CDN
- Affiliate IDs need to be configured for monetization
- Card ID format migration may affect existing users

### 9. **Archive & Upload**

```bash
# In Xcode:
1. Select "Any iOS Device" as destination
2. Product → Archive
3. Wait for archive to complete
4. Click "Distribute App"
5. Select "TestFlight & App Store"
6. Upload
7. Wait for processing (15-30 minutes)
```

### 10. **Post-Upload**

- [ ] Add "What to Test" notes in TestFlight
- [ ] Invite testers
- [ ] Monitor crash reports
- [ ] Collect feedback
- [ ] Plan next iteration

## 📝 Beta Testing Focus Areas

**Ask testers to specifically test:**
1. Card scanning accuracy
2. Deck building workflow
3. Collection organization
4. Performance with large collections
5. Buy button affiliate links
6. Any crashes or bugs
7. UI/UX feedback

## 🐛 Known Issues to Track

- [ ] Card ID format migration for existing users
- [ ] Scanner performance in low light
- [ ] Large collection performance (500+ cards)

## 🚀 Next Version Ideas

- Import/export collection
- Trade tracking
- Price history charts
- Push notifications for new sets
- iCloud sync
- iPad optimization
- Dark/light mode toggle
- Alternative themes

---

## Quick Reference

### Current Features:
✅ Local card database (8 sets)
✅ Camera scanning with OCR
✅ Collection management
✅ Wishlist
✅ Deck building (Core + Infinity formats)
✅ Deck validation
✅ Statistics and analytics
✅ Buy buttons (affiliate ready)
✅ Image caching
✅ Price estimation

### Requires Configuration:
⚠️ Affiliate IDs (for monetization)
⚠️ Privacy Policy URL
⚠️ App Store screenshots

### File Locations:
- Affiliate IDs: `Services/AffiliateService.swift`
- eBay App ID: `Services/PricingService.swift`
- Privacy: Create new file or settings view
