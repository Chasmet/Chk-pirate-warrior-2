const http = require('http');
const port = Number(process.env.PORT || 10000);
http.createServer((req, res) => {
  res.writeHead(200, {'content-type':'application/json'});
  res.end(JSON.stringify({ok:true, service:'goddo-cloud', mode:'godot-headless'}));
}).listen(port, '0.0.0.0', () => {
  console.log(`[Goddo Cloud] health server listening on :${port}`);
});
