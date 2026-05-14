// Content worker handler
// Processes article ingestion, company data updates, sector analysis
module.exports = {
  async process(body) {
    const { type, payload } = body;
    console.log(`[content-handler] Processing job type: ${type}`);

    switch (type) {
      case 'ARTICLE_INGEST':
        // Parse, index, store article
        break;
      case 'COMPANY_UPDATE':
        // Refresh company data from external source
        break;
      case 'SECTOR_REFRESH':
        // Recompute sector aggregations
        break;
      default:
        throw new Error(`Unknown content job type: ${type}`);
    }
  },
};
