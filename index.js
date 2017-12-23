const Express = require("express");
const QueryString = require("querystring");

const app = Express();

const PORT =
    process.env.PORT || 5000;


app.get('/', (req, res) => res.send('Hello World!'));


app.put("/process", (req, res) => {
    let body = "";
    req.on('data', data => {
        body += data;
    });
    req.on('end', () => {
        console.log(`Process Put: ${body}`);
        res.writeHead(200, "OK", {'Content-Type': 'text.plain'});
        res.end();
    });
});


app.listen(PORT, () => console.log(`Example app listening on port ${PORT}`));