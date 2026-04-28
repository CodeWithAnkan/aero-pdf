/// Returns true if the text for a page appears to be from a scanned image.
///
/// Heuristic: fewer than 30 characters of extracted text → likely a scan.
bool isPageTextScanned(String pageText) {
  return pageText.trim().length < 30;
}
