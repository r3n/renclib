Rebol [
    file: %upgrade.reb
    title: "Upgrade ren-c binaries"
    date: 24-Mar-2017
    version: 0.1.1
    notes: {
        scans for the lastest build for your OS regardless whether it's a debug build, cpp or c build
    }
]

upgrade: function [][
    page: to text! read http://metaeducation.s3.amazonaws.com/index.html
    either parse page [ thru <rebol> copy latest to </rebol> to end][
        latest: load latest
        either block: select latest unspaced [rebol/version/3 "." rebol/version/4 "." rebol/version/5][
            url: block/1
            either rebol/build < block/2 [
                file: last split-path url
                diff: difference block/2 rebol/build
                if diff < 0:02 [
                    return print "You have the latest build."
                ]
                write-stdout spaced [
                    "This build dated" rebol/build | 
                    "Newer build by" 
                    if diff/1 > 0 [reduce [diff/1 "hours"]] 
                    if diff/2 > 0 [reduce [diff/2 "mins"]]
                    if diff/3 > 0 [reduce [diff/3 "secs"]]
                    "is" file "from" block/2 newline "Download? (Y/n)"
                ]
                tf: input 
                either any [tf = "y" empty? tf][
                    print ["OK, downloading ..." file]
                    write file read url
                    if rebol/platform/1 = 'Windows [
                        print/only "Rename to r3.exe? (Y/n)"
                        tf: input
                        if any [tf = "y" empty? tf][
                            write %upgrade.cmd unspaced ["del r3.exe" newline "ren " form file " r3.exe" newline "r3"]
                            print "run upgrade.cmd"
                        ]
                    ]
                ][print "Upgrade declined"]
            ][
                print "You have the latest build."
            ]
        ][
            print "No upgrade found for your OS version."
        ]
    ][
        print "Unable to read update data."
    ]
    print "Finished."
]

upgrade
