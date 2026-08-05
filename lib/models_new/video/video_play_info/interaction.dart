class Interaction {
  int? graphVersion;

  Interaction({
    this.graphVersion,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) => Interaction(
    graphVersion: json["graph_version"],
  );
}
