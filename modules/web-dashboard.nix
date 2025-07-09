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
              
              /* Authentication banner */
              .auth-banner { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 30px; text-align: center; }
              .auth-banner h2 { margin: 0 0 10px 0; }
              .auth-banner p { margin: 0; opacity: 0.9; }
              .auth-button { display: inline-block; margin-top: 15px; padding: 12px 24px; background: rgba(255,255,255,0.2); color: white; border: 2px solid rgba(255,255,255,0.3); border-radius: 6px; text-decoration: none; transition: all 0.3s; }
              .auth-button:hover { background: rgba(255,255,255,0.3); text-decoration: none; color: white; }
              
              .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
              .service { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              .service h3 { margin-top: 0; color: #2c3e50; }
              .service a { color: #3498db; text-decoration: none; }
              .service a:hover { text-decoration: underline; }
              .status { padding: 5px 10px; border-radius: 4px; color: white; font-size: 12px; }
              .status.ready { background: #27ae60; }
              .status.pending { background: #f39c12; }
              .status.protected { background: #9b59b6; }
              .footer { text-align: center; margin-top: 40px; color: #666; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>&#127916; Cistern Media Server</h1>
              
              ${lib.optionalString (config.cistern.auth.enable && config.cistern.auth.method == "authentik") ''
              <div class="auth-banner">
                  <h2>🔐 Single Sign-On Enabled</h2>
                  <p>Your media server is protected with Authentik SSO. Sign in once to access all services.</p>
                  <a href="https://${config.cistern.auth.authentik.domain}" class="auth-button" target="_blank">
                      Sign In with Authentik →
                  </a>
              </div>
              ''}
              
              ${lib.optionalString (config.cistern.auth.enable && config.cistern.auth.method == "basic") ''
              <div class="auth-banner">
                  <h2>🔐 Authentication Required</h2>
                  <p>Your media server is protected with basic authentication. Use your username and password to access services.</p>
              </div>
              ''}
              
              <div class="services">
                  <div class="service">
                      <h3>Jellyfin <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Your main media server for watching movies and TV shows</p>
                      ${if config.cistern.auth.enable && config.cistern.auth.method == "authentik" then ''
                        <a href="https://''${config.cistern.auth.authentik.domain}/application/o/cistern-jellyfin/jellyfin/" target="_blank">Open Jellyfin (SSO) →</a>
                      '' else ''
                        <a href="http://''${window.location.hostname}:8096" target="_blank">Open Jellyfin →</a>
                      ''}
                  </div>
                  
                  <div class="service">
                      <h3>Sonarr <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Manage your TV show collection</p>
                      <a href="/sonarr" target="_blank">Open Sonarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Radarr <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Manage your movie collection</p>
                      <a href="/radarr" target="_blank">Open Radarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Prowlarr <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Manage indexers and search providers</p>
                      <a href="/prowlarr" target="_blank">Open Prowlarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Bazarr <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Manage subtitles for your media</p>
                      <a href="/bazarr" target="_blank">Open Bazarr →</a>
                  </div>
                  
                  <div class="service">
                      <h3>Transmission <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Download client for torrents</p>
                      <a href="/transmission" target="_blank">Open Transmission →</a>
                  </div>
                  
                  <div class="service">
                      <h3>SABnzbd <span class="status ${if config.cistern.auth.enable then "protected" else "ready"}">
                          ${if config.cistern.auth.enable then "Protected" else "Ready"}
                      </span></h3>
                      <p>Download client for Usenet</p>
                      <a href="/sabnzbd" target="_blank">Open SABnzbd →</a>
                  </div>
                  
                  <div class="service">
                      <h3>&#128230; NoiseFS <span class="status ready">Ready</span></h3>
                      <p>Distributed storage with privacy protection</p>
                      <a href="http://''${window.location.hostname}:8082" target="_blank">Open NoiseFS →</a>
                  </div>
                  
                  ${lib.optionalString (config.cistern.auth.enable && config.cistern.auth.method == "authentik") ''
                  <div class="service">
                      <h3>🔐 Authentik <span class="status ready">Ready</span></h3>
                      <p>Identity provider and single sign-on management</p>
                      <a href="https://${config.cistern.auth.authentik.domain}" target="_blank">Open Authentik →</a>
                  </div>
                  ''}
              </div>
              
              <div class="footer">
                  <p>Cistern Media Server is ready! ${if config.cistern.auth.enable then "Authentication is enabled for security." else "All services are open access."}</p>
                  <p>📋 <a href="/setup">View Setup Summary</a> | 📊 <a href="/logs">Setup Logs</a> | 🔧 <a href="/status">Configuration Status</a></p>
                  ${lib.optionalString (config.cistern.auth.enable && config.cistern.auth.method == "authentik") ''
                  <p>🔐 <a href="https://${config.cistern.auth.authentik.domain}/if/user/">User Profile</a> | 🚪 <a href="https://${config.cistern.auth.authentik.domain}/if/session-end/">Sign Out</a></p>
                  ''}
                  <p style="font-size: 12px; color: #999; margin-top: 20px;">
                    ✅ Auto-configured with Torrent + Usenet support | ✅ All services interconnected | 
                    ${if config.cistern.auth.enable then "🔐 Secured with authentication" else "⚠️ Open access mode"}
                  </p>
              </div>
          </div>
          
          <script>
              // Check authentication status for Authentik
              ${lib.optionalString (config.cistern.auth.enable && config.cistern.auth.method == "authentik") ''
              async function checkAuthStatus() {
                  try {
                      const response = await fetch('/outpost.goauthentik.io/auth/nginx', {
                          method: 'GET',
                          credentials: 'include'
                      });
                      
                      if (response.ok) {
                          // User is authenticated
                          const userName = response.headers.get('Remote-Name') || response.headers.get('Remote-User') || 'User';
                          const banner = document.querySelector('.auth-banner');
                          if (banner) {
                              banner.innerHTML = `
                                  <h2>👋 Welcome, ` + userName + `</h2>
                                  <p>You are signed in and have access to all services.</p>
                                  <a href="https://${config.cistern.auth.authentik.domain}/if/user/" class="auth-button" target="_blank">
                                      User Profile →
                                  </a>
                                  <a href="https://${config.cistern.auth.authentik.domain}/if/session-end/" class="auth-button" target="_blank" style="margin-left: 10px;">
                                      Sign Out →
                                  </a>
                              `;
                          }
                      }
                  } catch (error) {
                      console.log('Auth check failed:', error);
                  }
              }
              
              // Check auth status on page load
              document.addEventListener('DOMContentLoaded', checkAuthStatus);
              ''}
          </script>
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
      RestartSec = "5s";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8081 --directory /var/lib/media/dashboard";
      
      # Security
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadOnlyPaths = [ "/var/lib/media/dashboard" ];
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };

  # Open dashboard port
  networking.firewall.allowedTCPPorts = [ 8081 ];
}