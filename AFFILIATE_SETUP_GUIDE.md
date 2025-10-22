# Affiliate Integration Setup Guide

This guide will help you set up TCGPlayer and eBay affiliate integrations to monetize Inkwell Keeper.

---

## 📋 What You Need

### TCGPlayer Affiliate Program
- [ ] Apply at [Commission Junction (CJ)](https://www.cj.com/)
- [ ] Search for "TCGPlayer" advertiser
- [ ] Get approved (usually 3-7 days)
- [ ] Get your **Affiliate ID** from CJ dashboard

### eBay Partner Network
- [ ] Join [eBay Partner Network](https://partnernetwork.ebay.com/)
- [ ] Get approved (usually immediate)
- [ ] Get your **Campaign ID** from EPN dashboard
- [ ] Join [eBay Developers Program](https://developer.ebay.com/)
- [ ] Create an app to get **App ID** (for Finding API)

---

## 💰 Commission Rates

| Platform | Commission | Cookie Window | Notes |
|----------|------------|---------------|-------|
| **TCGPlayer** | 3-4% | 30 days | Best for singles |
| **eBay** | 3% | 24 hours | Great for bulk/rare cards |

---

## 🔧 Setup Instructions

### Step 1: Get Your Credentials

#### TCGPlayer
1. Go to [CJ.com](https://www.cj.com/) → Sign up
2. Search for "TCGPlayer" → Apply to program
3. Once approved, find your **Affiliate ID** in Account Settings
   - Format: `XXXXXXXX` (8-digit number)

#### eBay
1. Go to [eBay Partner Network](https://partnernetwork.ebay.com/) → Join
2. Dashboard → Get your **Campaign ID**
   - Format: `5338273279`
3. Go to [eBay Developers](https://developer.ebay.com/) → Register
4. Create an App → Get **App ID** (for pricing API)
   - Format: `YourAppN-InkwellK-PRD-XXXXXXXXXX-XXXXXXXX`

---

### Step 2: Add Credentials to Code

#### File: `Services/AffiliateService.swift`

Replace line 12-13:
```swift
// BEFORE:
private let tcgPlayerAffiliateID = "YOUR_TCGPLAYER_AFFILIATE_ID"
private let ebayPartnerNetworkCampaignID = "YOUR_EBAY_CAMPAIGN_ID"

// AFTER:
private let tcgPlayerAffiliateID = "12345678" // Your actual CJ affiliate ID
private let ebayPartnerNetworkCampaignID = "5338273279" // Your actual EPN campaign ID
```

#### File: `Services/PricingService.swift`

Replace line 272:
```swift
// BEFORE:
let ebayAppID = "YOUR_EBAY_APP_ID"

// AFTER:
let ebayAppID = "YourAppN-InkwellK-PRD-XXXXXXXXXX-XXXXXXXX" // Your actual eBay App ID
```

---

### Step 3: Test Affiliate Links

Build and run the app:

1. Open any card detail view
2. Scroll to "Buy This Card" section
3. Tap **TCGPlayer** or **eBay** button
4. Verify the URL includes your affiliate parameters:
   - TCGPlayer: `?partner=YOUR_ID`
   - eBay: `campid=YOUR_CAMPAIGN_ID`

---

## 🎯 How It Works

### User Flow:
```
User views card
  ↓
Sees estimated price
  ↓
Taps "Buy This Card"
  ↓
Chooses TCGPlayer or eBay
  ↓
Opens in Safari with YOUR affiliate link
  ↓
User makes purchase
  ↓
You earn commission! 💰
```

### Pricing Strategy:
- **No API Access?** → Uses smart estimation (already implemented)
- **With eBay API?** → Shows real sold prices
- **With TCGPlayer API?** → Shows marketplace prices (if approved)

---

## 📊 Revenue Optimization Tips

### 1. **Accurate Pricing = More Clicks**
   - Current estimation is solid
   - Add eBay API for real data (increases trust)
   - Update prices weekly via "Refresh All Prices"

### 2. **Strategic Button Placement**
   - ✅ Card detail view (already added)
   - 📝 TODO: Add to collection view cards
   - 📝 TODO: Add to wishlist items

### 3. **Multiple Options**
   - Always show both TCGPlayer + eBay
   - Let users compare prices
   - They'll pick best deal → still earns commission

### 4. **Variant-Specific Links**
   - Already implemented!
   - Searches include variant name (Foil, Enchanted, etc.)
   - More accurate results = higher conversion

---

## 🚀 Advanced Features (Already Built!)

### Multi-Platform Support
```swift
AffiliateService.shared.getBuyOptions(for: card)
```
Returns array of buy options with:
- Platform name
- Price (if available)
- Affiliate URL
- Tracking info

### Analytics Tracking
```swift
AffiliateService.shared.trackAffiliateClick(platform: "eBay", cardName: card.name)
```
Logs every click for performance monitoring

### Configuration Check
```swift
AffiliateService.shared.isConfigured() // Returns true when IDs are set
```

---

## 📱 UI Components

### BuyCardOptionsView
Full buy options with pricing (in Card Detail View)

### CompactBuyButton
Small "Buy" button for card tiles (ready to use)

### BuyCardSheet
Full-screen purchase options modal

---

## 🔍 TCGPlayer API Access (Optional)

TCGPlayer restricted API access in 2025, but there are alternatives:

### Option 1: Direct Affiliate Links (Current ✅)
- No API needed
- Search URLs with affiliate tags
- Works immediately
- Commission still earned

### Option 2: Third-Party APIs
- [JustTCG API](https://justtcg.com/) - Lorcana support
- Paid service but more reliable than scraping
- Easy integration if needed

### Option 3: Web Scraping (Use Carefully)
- Already partially implemented
- Can break if TCGPlayer changes HTML
- Not recommended as primary source

---

## ✅ Launch Checklist

Before going live:

- [ ] Join TCGPlayer Affiliate Program (CJ)
- [ ] Join eBay Partner Network
- [ ] Join eBay Developers Program
- [ ] Add TCGPlayer Affiliate ID to code
- [ ] Add eBay Campaign ID to code
- [ ] Add eBay App ID to code
- [ ] Test all affiliate links
- [ ] Verify commission tracking in dashboards
- [ ] Add disclosure: "Links support app development"

---

## 📈 Tracking Revenue

### TCGPlayer (via CJ)
- Dashboard: [cj.com](https://members.cj.com/)
- Reports: Daily/Monthly earnings
- Payment: Monthly (Net-20)

### eBay Partner Network
- Dashboard: [partnernetwork.ebay.com](https://partnernetwork.ebay.com/)
- Reports: Real-time tracking
- Payment: Monthly

---

## 🎉 You're All Set!

Once configured, every "Buy" button click can generate revenue while helping users find the best prices for their Lorcana cards!

**Questions?** Check the affiliate program documentation:
- [eBay Partner Network Docs](https://developer.ebay.com/promote/epn)
- [TCGPlayer Affiliate Info](https://www.tcgplayer.com/affiliate)
