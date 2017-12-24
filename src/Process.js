module.exports = $importAll([
    "child_process",
    "core:Native.System.IO.FileSystem:1.1.0"
]).then($imports => {
    const ChildProcess =
        $imports[0];

    const FileSystem =
        $imports[1];


    const $exec = command => options =>
        new Promise((resolve, reject) =>
            ChildProcess.exec(command, options, (error, stdout, stderr) =>
                error
                    ? reject(error)
                    : resolve([stdout, stderr])
            ));


    const $random = () =>
        Promise.resolve(Math.random());


    const $randomInRange = min => max =>
        $random()
            .then(r => Math.floor((r * (max - min) + min)));


    const $mkTmpName = prefix => suffix =>
        $randomInRange(0)(100000000)
            .then(r => `${prefix}${r}${suffix}`);


    const exec = type => script =>
        $mkTmpName("tmp")(".js")
            .then(tmpFileName =>
                FileSystem.writeFile(tmpFileName)(script)
                    .then(_ => $exec(`sle ${tmpFileName}`)({
                        encoding: "utf8",
                        timeout: 1000
                    }))
                    .then(r => {
                        FileSystem.removeAll(tmpFileName)
                            .catch(console.error);
                        return Promise.resolve(r);
                    })
                    .catch(err => {
                        FileSystem.removeAll(tmpFileName)
                            .catch(console.error);
                        return Promise.reject(err);
                    })
            );


    return {
        exec
    };
});