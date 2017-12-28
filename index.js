require("sle");

$importAll([
    "express",
    "./src/Process"
]).then($imports => {
    const Express =
        $imports[0];

    const Process =
        $imports[1];

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
                console.log(body);
                resolve(body);
            });
        });


    const stringToJSON = input =>
        new Promise((resolve, reject) => {
            try {
                resolve(JSON.parse(input));
            }
            catch (e) {
                reject({status: e.status, message: e.message});
            }
        });


    app.use(Express.static("www"));


    app.put("/api/process", (req, res) =>
        loadBody(req, res)
            .then(stringToJSON)
            .then(body => Process.exec(body.type)(body.script))
            .then(result => {
                res.writeHead(200, "OK", {'Content-Type': 'application/json'});
                res.end(JSON.stringify({
                    stdout: result[0],
                    stderr: result[1]
                }, null, 2));
            })
            .catch(err => {
                res.writeHead(500, "" + err.status, {'Content-Type': 'application/json'});
                res.end(JSON.stringify(err, null, 2));
            }));


    app.listen(PORT, () => console.log(`Example app listening on port ${PORT}`));
});
