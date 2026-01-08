{
  bots = [
    "maren"
    "sonja"
    "gunnar"
    "melinda"
  ];

  guildId = "YOUR_GUILD_ID";

  routing = {
    maren = {
      channels = [ "help" "maren" ];
      requireMention = true;
    };
    sonja = {
      channels = [ "sonja" ];
      requireMention = true;
    };
    gunnar = {
      channels = [ "gunnar" ];
      requireMention = true;
    };
    melinda = {
      channels = [ "melinda" ];
      requireMention = true;
    };
  };
}
