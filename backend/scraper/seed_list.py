"""
Fixed seed list of trusted DPDP learning sources.
Checked daily for new content.
"""

SEED_URLS = [
    # Official / Regulatory
    "https://www.meity.gov.in/data-protection-framework",

    # Law firm analysis
    "https://www.mondaq.com/india/data-protection/",
    "https://www.amsshardul.com/insights/?category=data-protection",
    "https://www.dlapiperdataprotection.com/?t=law&c=IN",

    # Practitioner sites
    "https://www.dpdpa.com/",
    "https://exmachina.in/",
    "https://www.smritiparsheera.com/research/privacy-surveillance",

    # Civil society / rights orgs
    "https://internetfreedom.in/tag/dpdp/",
    "https://sflc.in/category/data-protection/",

    # Podcasts (RSS / landing pages)
    "https://www.ey.com/en_in/media/podcasts/gateway-to-data-privacy-and-protection",

    # Learning platforms
    "https://blog.ipleaders.in/?s=DPDP",
    "https://iapp.org/resources/topics/india-2/",

    # YouTube search pages (handled specially in extractor)
    "https://www.youtube.com/results?search_query=DPDP+Act+2023+explained",
    "https://www.youtube.com/results?search_query=Digital+Personal+Data+Protection+India",
]

# Brave search queries run weekly to discover new sources
DISCOVERY_QUERIES = [
    "DPDP Act 2023 site:mondaq.com",
    "Digital Personal Data Protection Rules 2025 compliance",
    "DPDP Act explained India lawyer 2025",
    "DPDPA podcast India 2025",
    "Data Protection Board India news 2025",
]
