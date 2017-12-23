require("sle");

$importAll([
    "express",
    "querystring",
    "core:Native.Data.Array:1.2.0"
]).then($imports => {
    const Express = $imports[0];
    const QueryString = $imports[1];

    const app = Express();

    const PORT =
        process.env.PORT || 5000;


    const loadBody = (req, res) =>
        new Promise((resolve, reject) => {
            let body = "";
            req.on('error', error => {
                reject(error);
            });
            req.on('data', data => {
                body += data;
            });
            req.on('end', () => {
                resolve(body);
            });
        });


    app.get('/', (req, res) => res.send('Hello World!'));


    app.put("/process", (req, res) =>
        loadBody(req, res)
            .then(body => {
                console.log(`Process Put: ${body}`);
                res.writeHead(200, "OK", {'Content-Type': 'text/plain'});
                res.end();
            })
            .catch(err => {
                console.log(`Error: ${err}`);
                res.writeHead(500, "" + err.status, {'Content-Type': 'application/json'});
                res.end(JSON.stringify(err, null, 2));
            }));


    app.listen(PORT, () => console.log(`Example app listening on port ${PORT}`));
});
