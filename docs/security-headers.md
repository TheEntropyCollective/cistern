# Nginx Security Headers Configuration

This document describes the security headers configuration available in Cistern's nginx module.

## Overview

The nginx module now includes comprehensive security headers that can be configured to protect your media server from common web vulnerabilities. All security headers are enabled by default with sensible values for media server usage.

## Configuration Options

### Basic Enable/Disable

```nix
{
  # Enable or disable all security headers (default: true)
  cistern.nginx.securityHeaders.enable = true;
}
```

### HTTP Strict Transport Security (HSTS)

HSTS forces browsers to use HTTPS connections and prevents protocol downgrade attacks.

```nix
{
  cistern.nginx.securityHeaders.hsts = {
    enable = true;              # Enable HSTS (default: true)
    maxAge = 63072000;         # Max age in seconds (default: 2 years)
    includeSubdomains = true;   # Apply to subdomains (default: true)
    preload = false;           # Enable HSTS preloading (default: false)
  };
}
```

**Note**: HSTS headers are only sent when SSL is enabled (`cistern.ssl.enable = true`).

### Content Security Policy (CSP)

CSP helps prevent XSS attacks by controlling which resources can be loaded.

```nix
{
  # Default CSP is configured for media server compatibility
  cistern.nginx.securityHeaders.contentSecurityPolicy = 
    "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline' 'unsafe-eval'; " +
    "frame-ancestors 'self';";
}
```

The default policy is permissive to ensure compatibility with media services like Jellyfin, Sonarr, and Radarr.

### Frame Options

Controls whether your site can be embedded in iframes.

```nix
{
  # Options: "DENY", "SAMEORIGIN", "ALLOW-FROM"
  cistern.nginx.securityHeaders.frameOptions = "SAMEORIGIN";  # default
}
```

### Other Security Headers

```nix
{
  # Prevent MIME type sniffing
  cistern.nginx.securityHeaders.contentTypeOptions = true;  # default
  
  # Enable XSS protection in older browsers
  cistern.nginx.securityHeaders.xssProtection = true;  # default
  
  # Control referrer information
  # Options: "no-referrer", "no-referrer-when-downgrade", "same-origin", 
  #          "origin", "strict-origin", "origin-when-cross-origin",
  #          "strict-origin-when-cross-origin", "unsafe-url"
  cistern.nginx.securityHeaders.referrerPolicy = "strict-origin-when-cross-origin";  # default
  
  # Permissions Policy (formerly Feature Policy)
  cistern.nginx.securityHeaders.permissionsPolicy = 
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), " +
    "magnetometer=(), microphone=(), payment=(), usb=()";  # default
}
```

## CORS Configuration

Cross-Origin Resource Sharing (CORS) headers can be configured for API access from external applications.

```nix
{
  cistern.nginx.cors = {
    enable = false;  # Disabled by default
    
    # List of allowed origins (* for all)
    allowedOrigins = [ "*" ];
    
    # Allowed HTTP methods
    allowedMethods = [ "GET" "POST" "PUT" "DELETE" "OPTIONS" ];
    
    # Allowed request headers
    allowedHeaders = [ "Authorization" "Content-Type" "X-Requested-With" ];
    
    # Headers to expose to the client
    exposeHeaders = [];
    
    # Max age for preflight cache (in seconds)
    maxAge = 86400;  # 24 hours
    
    # Allow credentials (cookies, auth headers)
    allowCredentials = true;
  };
}
```

### Example: Enable CORS for Mobile App

```nix
{
  cistern.nginx.cors = {
    enable = true;
    allowedOrigins = [ 
      "https://myapp.example.com" 
      "capacitor://localhost"  # For mobile apps
    ];
    allowCredentials = true;
  };
}
```

## Common Configurations

### Strict Security (May break some features)

```nix
{
  cistern.nginx.securityHeaders = {
    frameOptions = "DENY";
    contentSecurityPolicy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';";
  };
}
```

### Development Environment

```nix
{
  # Relax security for development
  cistern.nginx.securityHeaders.hsts.enable = false;
  cistern.nginx.cors = {
    enable = true;
    allowedOrigins = [ "*" ];
  };
}
```

### Public Internet Deployment

```nix
{
  cistern.nginx.securityHeaders = {
    hsts = {
      enable = true;
      maxAge = 63072000;  # 2 years
      includeSubdomains = true;
      preload = true;  # Submit to HSTS preload list
    };
  };
}
```

## Troubleshooting

### Headers Not Appearing

1. Check that `cistern.nginx.securityHeaders.enable = true`
2. For HSTS, ensure `cistern.ssl.enable = true`
3. Verify nginx configuration with `nginx -t`

### CORS Issues

1. Check browser console for specific CORS errors
2. Ensure the origin is in `allowedOrigins` list
3. For credentials, ensure `allowCredentials = true`
4. OPTIONS requests are automatically handled when CORS is enabled

### CSP Violations

1. Check browser console for CSP violation reports
2. Adjust `contentSecurityPolicy` to allow required resources
3. Use browser developer tools to identify blocked resources

## Security Considerations

1. **HSTS**: Once enabled with a long `maxAge`, browsers will enforce HTTPS. Ensure SSL is properly configured before enabling.

2. **CSP**: The default policy is permissive for compatibility. Consider tightening it based on your security requirements.

3. **CORS**: Only enable CORS if you need cross-origin access. Be specific with `allowedOrigins` rather than using `*`.

4. **Frame Options**: Set to `DENY` if you don't need iframe embedding, or use `SAMEORIGIN` to allow embedding only from your own domain.

## Testing

You can test security headers using:

1. Browser developer tools (Network tab, Response Headers)
2. Online tools like securityheaders.com
3. Command line: `curl -I https://your-server.local`

Example test:
```bash
curl -I https://media-server.local | grep -i "strict-transport\|x-frame\|x-content\|content-security"
```