class Utils {
  static List<double> parseEmbedding(String embeddingJson) {
    return embeddingJson.split(',').map(double.parse).toList();
  }

  static String embeddingToString(List<double> embedding) {
    return embedding.join(',');
  }
}
