{ config, pkgs, lib, ... }:

{
  # Simple web dashboard for media server status
  
  # Create dashboard files
  systemd.tmpfiles.rules = [
    "d /var/lib/media/dashboard 0755 media media -"
    "L+ /var/lib/media/dashboard/index.html 0644 media media - ${pkgs.writeText "dashboard.html" ''
      <!DOCTYPE html>
      <html>
      <head>
          <title>Cistern Media Server</title>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
              .container { max-width: 1200px; margin: 0 auto; }
              h1 { color: #333; text-align: center; }
              .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
              .service { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              .service h3 { margin-top: 0; color: #2c3e50; }
              .service a { color: #3498db; text-decoration: none; }
              .service a:hover { text-decoration: underline; }
              .status { padding: 5px 10px; border-radius: 4px; color: white; font-size: 12px; }
              .status.ready { background: #27ae60; }
              .status.pending { background: #f39c12; }
              .footer { text-align: center; margin-top: 40px; color: #666; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>&#127916; Cistern Media Server</h1>
              
              <div class="services">
                  <div class="service">
                      <h3>Jellyfin <span class="status ready">Ready</span></h3>
                      <p>Your main media server for watching movies and TV shows</p>
                      <a href="http://''${window.location.hostname}:8096" target="_blank">Open Jellyfin →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Sonarr <span class="status ready">Ready</span></h3>
                      <p>Manage your TV show collection</p>
                      <a href="http://''${window.location.hostname}:8989" target="_blank">Open Sonarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Radarr <span class="status ready">Ready</span></h3>
                      <p>Manage your movie collection</p>
                      <a href="http://''${window.location.hostname}:7878" target="_blank">Open Radarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Prowlarr <span class="status ready">Ready</span></h3>
                      <p>Manage indexers and search providers</p>
                      <a href="http://''${window.location.hostname}:9696" target="_blank">Open Prowlarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Bazarr <span class="status ready">Ready</span></h3>
                      <p>Manage subtitles for your media</p>
                      <a href="http://''${window.location.hostname}:6767" target="_blank">Open Bazarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Transmission <span class="status ready">Ready</span></h3>
                      <p>Download client for torrents</p>
                      <a href="http://''${window.location.hostname}:9091" target="_blank">Open Transmission →</a>
                  </div>
                  
                  <div class="service">
                      <h3>SABnzbd <span class="status ready">Ready</span></h3>
                      <p>Download client for Usenet</p>
                      <a href="http://''${window.location.hostname}:8080" target="_blank">Open SABnzbd →</a>
                  </div>
                  
                  <div class="service">
                      <h3>&#128230; NoiseFS <span class="status ready">Ready</span></h3>
                      <p>Distributed storage with privacy protection</p>
                      <a href="http://''${window.location.hostname}:8082" target="_blank">Open NoiseFS →</a>
                  </div>
              </div>
              
              <div class="footer">
                  <p>Cistern Media Server is ready! All services are pre-configured and ready to use.</p>
                  <p>📋 <a href="/setup">View Setup Summary</a> | 📊 <a href="/logs">Setup Logs</a> | 🔧 <a href="/status">Configuration Status</a></p>
                  <p style="font-size: 12px; color: #999; margin-top: 20px;">
                    ✅ Auto-configured with Torrent + Usenet support | ✅ All services interconnected | ✅ Zero manual setup required
                  </p>
              </div>
          </div>
      </body>
      </html>
    ''}"
  ];

  # Simple HTTP server for dashboard
  systemd.services.media-dashboard = {
    description = "Media server dashboard";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "media";
      Group = "media";
      Restart = "always";
      WorkingDirectory = "/var/lib/media/dashboard";
    };
    
    script = ''
      ${pkgs.python3}/bin/python3 -m http.server 8081
    '';
  };

  # Add dashboard to nginx
  services.nginx.virtualHosts."${config.networking.hostName}.local".locations = {
    "/dashboard" = {
      proxyPass = "http://127.0.0.1:8081";
    };
    "/status" = {
      alias = "/var/lib/media/auto-config/setup.log";
      extraConfig = ''
        default_type text/plain;
      '';
    };
    "/setup" = {
      alias = "/var/lib/media/auto-config/setup-summary.html";
      extraConfig = ''
        default_type text/html;
      '';
    };
    "/logs" = {
      alias = "/var/lib/media/auto-config/setup.log";
      extraConfig = ''
        default_type text/plain;
      '';
    };
  };
}