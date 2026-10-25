package co.brevinb.inkwellkeeper.ui.more

/** One release in the changelog — mirrors the iOS What's New entries. */
data class ChangelogEntry(
    val version: String,
    val date: String,
    val features: List<String>,
    val improvements: List<String>,
    val bugFixes: List<String>,
    val inProgress: List<String>,
)

// Add new versions at the top of this list (kept in step with iOS WhatsNewView).
val changelogEntries: List<ChangelogEntry> = listOf(
    ChangelogEntry(
        version = "3.5.1",
        date = "October 2026",
        features = listOf(
            "Hyperia City is complete: all 18 Epics and 18 Enchanteds are in, ready to scan and collect on release day"
        ),
        improvements = listOf(
            "Corrected card text on a couple of Hyperia City cards"
        ),
        bugFixes = listOf(),
        inProgress = listOf("Price alerts")
    ),
    ChangelogEntry(
        version = "3.5.0",
        date = "October 2026",
        features = listOf(
            "Storage is here! Track where every card lives — binders, troves, deck boxes, storage boxes, and bulk bins — right from the Collection tab",
            "Binders you flip through page by page, with 4, 9, or 12-pocket pages, single or double-sided, and drag-to-rearrange",
            "Set checklist binders show the cards you're still missing in their numbered pockets, with an optional master set layout for foils (Pro)",
            "Bookshelf: every binder and box on a wooden bookcase — tap one to pull it off the shelf and open it",
            "Share My Bookshelf as an image",
            "Build a deck into a deck box: a pull list shows where each card is, and taking it apart puts every card back in its pocket",
            "Select several cards and move them to another binder, box, or back to Unsorted in one go",
            "Scan new cards straight into a binder or box (Pro)",
            "Starlight and Holofoil cover finishes, plus unlimited binders and boxes (Pro)"
        ),
        improvements = listOf(
            "Card details now show exactly where every copy is stored",
            "Decks are now ideas until you build them, so a deck no longer holds on to your cards — build it into a deck box when you're ready",
            "Export has a new Location column, and JSON backups now include your binders and boxes",
            "Use any JSON backup from Inkwell Keeper to restore your collection, binders, and boxes from Import"
        ),
        bugFixes = listOf(
            "JSON backups can now actually be restored — Import didn't recognize them before",
            "Fixed the Filters button squishing onto two lines on smaller iPhones"
        ),
        inProgress = listOf("Price alerts")
    ),
    ChangelogEntry(
        version = "3.4.1",
        date = "September 2026",
        features = listOf(
            "AI decks now follow your format's rules: 60 cards, max 4 copies (reprints included), only your inks and legal sets, with a banner showing the result (Pro)",
            "Rate AI decks, completions, swaps, and strategy guides, then try again using your feedback (Pro)",
            "Save share cards straight to Photos, or copy them to paste into Discord",
            "Hyperia City cards slowly coming in, hidden by default to avoid spoilers"
        ),
        improvements = listOf(
            "Dual-ink cards now appear in AI decks that play both of their inks",
            "AI decks have more inkable cards and a better cost curve",
            "Core Constructed updated for the current rotation (Fabled through Attack of the Vine!)"
        ),
        bugFixes = listOf(
            "Older printings of cards reprinted in a legal set are no longer marked illegal in Core decks",
            "Improve Deck no longer shows an unused \"Add to Deck\" button"
        ),
        inProgress = listOf("Price alerts", "Storage tracking: Binders, Troves, Bins, etc")
    ),
    ChangelogEntry(
        version = "3.4.0",
        date = "September 2026",
        features = listOf(
            "Collection Value: track what your collection is worth over time",
            "Biggest Movers: see which of your cards gained and lost the most each week",
            "Highs & Lows: spot cards at the top or bottom of their price range",
            "Foil Premium: compare what your foils are worth against everything else",
            "Cost vs Value: record what you paid and track your gain or loss",
            "Trade Calculator: value both sides of a trade, scan cards straight in, and share the result"
        ),
        improvements = listOf(
            "Stats is now a main tab, one tap from anywhere",
            "Export now includes purchase price, total value, and gain/loss",
            "Clearer, more readable share cards"
        ),
        bugFixes = listOf(
            "Fixed card prices that were being matched to the wrong card",
            "Fixed the subscription options being hidden behind the tab bar"
        ),
        inProgress = listOf("Price alerts", "Storage tracking: Binders, Troves, Bins, etc")
    ),
    ChangelogEntry(version = "3.3.4", date = "September 2026", features = listOf(), improvements = listOf("Significant improvements for iPad users"), bugFixes = listOf(), inProgress = listOf("Better AI Features", "Storage tracking: Binders, Troves, Bins, etc")),
    ChangelogEntry(version = "3.3.3", date = "September 2026", features = listOf("Added the ability to add foil cards to decks instead of just regular cards"), improvements = listOf(), bugFixes = listOf(), inProgress = listOf("Better AI Deck Building")),
    ChangelogEntry(version = "3.3.2", date = "August 2026", features = listOf("Added filter based off card price"), improvements = listOf("Improved Scanning"), bugFixes = listOf(), inProgress = listOf()),
    ChangelogEntry(
        version = "3.3.1",
        date = "August 2026",
        features = listOf(
            "Pre-release promos added — the new PD1 promo series (Attack of the Vine pre-release and event cards) is in the card database with images, plus Buzz Lightyear - Space Ranger in Promo Set 3"
        ),
        improvements = listOf(
            "Promo cards now show real market prices — Promo Sets 1–3, PD1, D23, Challenge, and event promos"
        ),
        bugFixes = listOf(
            "Fixed the Rules Assistant answering every question with an error"
        ),
        inProgress = listOf()),
    ChangelogEntry(
        version = "3.3.0",
        date = "August 2026",
        features = listOf(
            "Format Coconut is here! Build singleton decks around any of the 18 beta leaders — with official leader card art, deck validation, and leaders that travel in shared deck links",
            "Coconut games in the Lore Counter — pick your leader per player, play to 25 lore, and tap your leader anytime to re-read its ability",
            "Draw Opening Hand — deal a sample 7 from any deck, set cards aside for the alteration, and feel your curve before you sleeve up",
            "AI deck improvements — full decks now get suggested swaps (cut this, add that) you can toggle and apply with one tap (Pro)"
        ),
        improvements = listOf(
            "AI upgraded to newer models that know the modern Lorcana card pool — smarter deck suggestions and rulings",
            "The AI Rules Assistant knows Format Coconut's rules",
            "Deck AI is faster and more reliable — no more freeze when results arrive, and clear error messages with retry when something goes wrong",
            "Text deck lists now carry your Coconut leader, and pasting one back recreates the deck"
        ),
        bugFixes = listOf(
            "Coconut games no longer celebrate a win at 20 lore — the target is correctly 25",
            "Opening the AI Strategy Guide no longer clears your deck builder results"
        ),
        inProgress = listOf()),
    ChangelogEntry(
        version = "3.2.0",
        date = "August 2026",
        features = listOf(
            "Share decks as links — friends open them right in the app, or view the full deck in any web browser, no app needed",
            "Import decks by pasting a deck list from Dreamborn, Discord, or anywhere (\"4 Elsa - Snow Queen\" style) — and export yours the same way",
            "Ask About This Card on every card — instant AI answers on rulings, interactions, and strategy (Pro)",
            "Free Keyword Glossary — every Lorcana keyword explained, works offline, in the Rules tab",
            "Share AI rulings as images — settle rules debates in your group chat",
            "Attach cards to rules questions straight from your collection, and tap any card in the chat to view it full size",
            "Price trend charts now have a beautiful share card"
        ),
        improvements = listOf(
            "Rules Assistant fully updated to the July 2026 Comprehensive Rules — Attack of the Vine keywords, all six Shift variants, dual-ink cards, and current formats. Rules now update automatically between app releases",
            "Redesigned rules chat — answers read like a rules reference, questions remember which cards they were about, and smart follow-up suggestions keep the conversation going",
            "One streamlined deck share menu — link, image, and text list in one place",
            "Multi-scan review adds your whole stack in one quick save",
            "AI deck builder now tells you when something goes wrong and lets you retry"
        ),
        bugFixes = listOf(
            "Ask About This Card now works every time, not just the first",
            "Rules answers stream in smoothly without the screen jumping",
            "Long shared rulings no longer get cut off in the image",
            "Failed rules questions no longer count against your daily limit",
            "Completing an already-full deck now explains itself instead of silently failing"
        ),
        inProgress = listOf()),
    ChangelogEntry(
        version = "3.1.0",
        date = "July 2026",
        features = listOf(
            "Import your collection straight from the official Disney Lorcana app — just paste your backup link",
            "Collectr CSV import, plus support for LorcanaExporter files",
            "Price history charts on every card — see how values trend over time",
            "See both Market and TCGplayer Low prices for every card",
            "Filter sets by ink color, rarity, variant, and price — and sort by price or rarity",
            "Card text now shows real Lorcana symbols instead of {E} and {S} codes"
        ),
        improvements = listOf(
            "Bulk imports now finish in seconds instead of minutes",
            "Enchanted, Epic, and Iconic printings import correctly from Dreamborn files",
            "Every set's card images are now bundled for faster, offline browsing",
            "Adding cards is clearer — quantity starts at zero and shows what you already own"
        ),
        bugFixes = listOf(
            "Foil cards now show their real foil market price",
            "Attack of the Vine Epic, Enchanted, and Iconic rarities corrected",
            "Epic cards no longer display as Common rarity",
            "Rapid scanning now shows the correct price for each card",
            "Swipe-dismissing the scan review after adding no longer leaves cards pending",
            "Fixed cards occasionally not rendering in the collection grid until scrolled"
        ),
        inProgress = listOf()),
    ChangelogEntry(
        version = "3.0.0",
        date = "June 2026",
        features = listOf("Added Set 13 Attack of the Vine!", "Added a share feature to share your pulls with your friends and community!", "Added iCloud sync so you can view your collection on all your devices."),
        improvements = listOf(
            "Improved scanning speed and quality.", "Improved pricing accuracy", "Improved Deck view"
        ),
        bugFixes = listOf("bugfix with sets not showing the right cards"),
        inProgress = listOf()),
    ChangelogEntry(
        version = "2.3.1",
        date = "June 2026",
        features = listOf(),
        improvements = listOf(
            "Sets View now allows you to search by card number, ex: Set 11 type 105 and it pulls up Donald Duck - Nephew Fred"
        ),
        bugFixes = listOf("Toolbar buttons were not showing up on iPad"),
        inProgress = listOf("Coming Soon: iCloud sync between devices")),
    ChangelogEntry(
        version = "2.3.0",
        date = "May 2026",
        features = listOf(
            "Reworked Stats tab — rarity donut, ink-color and cost-curve charts, card type breakdown, inkable ratio, top 10 most valuable cards, value by set, plus set completion and recent additions",
            "About Pricing sheet (Stats tab and Settings → Legal) explains where prices come from and why some cards may not have data"
        ),
        improvements = listOf(
            "Pricing is now exclusively live Cardmarket data — no more estimated values when market data isn't available",
            "Cards without market data display \"—\" instead of a fabricated price",
            "Refresh Prices button added to the Stats tab",
            "Top valuable cards now show a variant badge so Normal, Foil, and Enchanted versions are easy to tell apart"
        ),
        bugFixes = listOf(
            "Fixed Bulk Add corrupting Enchanted/Epic/Iconic/Promo cards — each card now keeps its actual variant instead of being forced to Normal",
            "Fixed Missing filter and set-completion percentage disagreeing after Bulk Add",
            "One-time repair migrates any collections affected by the previous Bulk Add bug, merging duplicate rows automatically"
        ),
        inProgress = listOf(
            "Cardmarket pricing coverage continues to improve — report missing cards from Settings → Report an Issue"
        )
    ),
    ChangelogEntry(
        version = "2.2.1",
        date = "May 2026",
        features = listOf(),
        improvements = listOf(),
        bugFixes = listOf(
            "Fixed scanned card photos being automatically saved to the collection — photos are now only attached when you explicitly add one",
            "Fixed What's New popup reappearing on every launch when dismissed by swipe"
        ),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "2.2.0",
        date = "May 2026",
        features = listOf(
            "Wilds Unknown - Added support for the new Wilds Unknown set with all 242 cards",
            "Lorcana Challenge Year 3 - Added the 14-card Lorcana Challenge Year 3 promo set"
        ),
        improvements = listOf(
            "Updated Promo Set 1 with the Mickey Mouse - True Friend international variant",
            "Added the four new Dalmatian Puppy alternate-art variants to Into the Inklands",
            "Sets are now consistently ordered by set number across the app, with promos and special sets grouped at the end",
            "Cards within a set now always display in collector-number order"
        ),
        bugFixes = listOf(),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "2.1.0",
        date = "April 2026",
        features = listOf(
            "New Sets - Added Promo Set 3 and EPCOT Festival of the Arts cards",
            "Edit Deck Info - You can now edit deck name, format, ink colors, and archetype after creation",
            "Streamlined Import - Importing from Dreamborn now processes and adds cards in a single step with live stats",
            "Card Photos - Attach photos of your physical cards to any card in your collection"
        ),
        improvements = listOf(
            "Major performance improvements - Scrolling, filtering, and searching are significantly faster with large collections",
            "Dreamborn CSV import completely rewritten to match current export format with proper foil detection",
            "Updated all card data to latest from LorCast API",
            "AI deck completion now correctly fills to 60 cards instead of going over",
            "Corrected set ordering across the app (Fabled is now Set 9)"
        ),
        bugFixes = listOf(
            "Fixed foil cards from Dreamborn imports being added as normal variants",
            "Fixed set progress calculations being slow with large collections",
            "Fixed background animation causing unnecessary CPU usage",
            "Fixed card images reloading every time you scrolled"
        ),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "2.0.0",
        date = "March 2026",
        features = listOf("More accurate pricing coming from TCGTrader", "Added CardMarket", "AI Deck Building (Pro Feature)", "Improved Set Tracking", "Improved Scanning: New mode as Multi Scan", "Added Search for all cards without going to scanning tab"),
        improvements = listOf("Your collection now shows which cards belong to which deck and how many 'available' cards you have", "You can now add cards to wishlist easier"),
        bugFixes = listOf("Previously cards that are reprinted appeard as the same card with a tag showing which set they belonged to, now they act as separate cards", "Scanning didn't grab cards with different rarity, now it should"),
        inProgress = listOf("Pricing isn't perfect, thats being improved", "AI Deck Building and AI Rules is a constant effort to improve quality of responses ", "Continuing to improve app performance")
    ),
    ChangelogEntry(
        version = "1.4.0",
        date = "February 2026",
        features = listOf(
            "Lore Counter - Track lore for two players with a built-in game counter, includes quick access to official rules",
            "Rules Assistant - AI-powered rules assistant that can answer questions about Lorcana rules and card interactions",
            "Multi-Card References - Attach up to 4 cards at once to ask the Rules Assistant about card interactions",
            "Interactive Foil Effect - Foil cards now feature a holographic tilt effect using your device's motion sensors"
        ),
        improvements = listOf(
            "Updated Winterspell set with all released cards",
            "Improved Play tab UI with lore counter and rules access",
            "Enhanced LLM rules logic with comprehensive game rules coverage",
            "Card text is now used as the authoritative source for rules questions"
        ),
        bugFixes = listOf(),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "1.3.0",
        date = "January 2026",
        features = listOf(
            "Winterspell Set - Added support for the new Winterspell set with 175 cards (more coming as they're revealed)",
            "6 New Starter Decks - Added starter decks for Azurite Sea, Archazia's Island, and Reign of Jafar",
            "Automated Updates - Card data now automatically checked weekly for new cards and sets"
        ),
        improvements = listOf(
            "All card data synced with latest from LorCast API",
            "Added Dalmatian Puppy variant cards (4a-4e) to Into the Inklands",
            "Added Mickey Mouse international promo variants (Japanese & Chinese)",
            "Updated set card counts to match official totals"
        ),
        bugFixes = listOf(),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "1.2.0",
        date = "January 2026",
        features = listOf(
            "Dynamic Export Fields - Choose exactly which fields to include in your export from 19 available options including card number, rarity, ink color, stats, price, and more",
            "Multiple Export Formats - Export to Custom CSV, Dreamborn Bulk Add, Dreamborn Collection, Lorcana HQ, or JSON Backup",
            "Variant Filtering - Filter your collection by Normal, Foil, Enchanted, Promo, or Special variants to easily track your master set progress",
            "Multi-Variant Adding - Add both Normal and Foil copies of a card at the same time instead of searching twice",
            "Collapsible Filter Bar - Filters now collapse to save screen space, with active filters shown as removable pills"
        ),
        improvements = listOf(
            "Export now includes card collector numbers",
            "Quick export presets (Basic, Standard, Full) for fast field selection",
            "Filter bar shows count of active filters",
            "Clear All Filters button to quickly reset filters",
            "Sort option always visible even when filters collapsed",
            "Export formats show file type badges (.csv, .json)"
        ),
        bugFixes = listOf(),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "1.1.0",
        date = "November 2025",
        features = listOf(
            "DISCLAIMER: A big overhaul happened to get all the missing cards into the app, if you notice any issues with your cards they may have to be re-added. We apologize for the inconvenience",
            "Enhanced character normalization for imports - Better handling of special characters like apostrophes and ellipsis",
            "Improved image loading for newly added cards"
        ),
        improvements = listOf(
            "Fixed set count display for reprinted cards",
            "Promo variants now correctly treated as separate cards",
            "Better matching of cards across different sets",
            "More reliable image caching and display",
            "Added enchanted, epic and iconic images",
            "Pricing has been inaccurate, until I can get TCGPlayer API access I've temporarily removed the pricing. There are still links that take you to TCGPlayer and eBay"
        ),
        bugFixes = listOf(
            "Fixed incorrect set counts showing for collections",
            "Fixed Promo cards incorrectly matching with Normal variants",
            "Resolved import failures for cards with special characters"
        ),
        inProgress = listOf()
    ),
    ChangelogEntry(
        version = "1.0.0",
        date = "October 2025",
        features = listOf(
            "Track your Lorcana card collection",
            "Create and manage wishlists",
            "Scan cards using your camera",
            "Import collections from CSV files",
            "Import collection from Dreamborn",
            "Export your collection data",
            "View card prices and market data",
            "Filter and sort your collection",
            "Track collection progress by set"
        ),
        improvements = listOf(),
        bugFixes = listOf(),
        inProgress = listOf()
    )
)
