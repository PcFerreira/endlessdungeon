export function isPrivateLanHost(host) {
  if (['localhost','::1','[::1]'].includes(host)) return true;
  const parts = host.split('.');
  if (parts.length !== 4 || parts.some(part=>!/^\d+$/.test(part) || Number(part)>255 || String(Number(part))!==part)) return false;
  const [first,second] = parts.map(Number);
  return first===127 || first===10 || first===172 && second>=16 && second<=31 || first===192 && second===168;
}

export function requiredFeatures(missing,{protocol,hostname,threads}) {
  if (protocol !== 'http:' || threads || !isPrivateLanHost(hostname)) return missing;
  return missing.filter(feature=>feature !== 'Secure Context - Check web server configuration (use HTTPS)');
}

export function launchArguments(args,{protocol,hostname,threads,secureContext}) {
  if (protocol !== 'http:' || threads || secureContext || !isPrivateLanHost(hostname)) return args;
  return [...args,'--audio-driver','Dummy'];
}
