REBOL [title: "A tiny static HTTP server" author: 'abolka date: 2009-11-04]

;; INIT
-help: does [print {
USAGE: r3 webserver.reb [OPTIONS]
OPTIONS:
  -h, -help, --help : this help
  -q      : quiet
  NUMBER  : port number [8000]
  OTHER   : web root [system/options/path]
e.g.: 8080 /my/web/root quiet
}]

root: system/options/path
port: 8000
verbose: true
args: system/options/args
for-each a args [case [
    find ["-h" "-help" "--help"] a [-help quit]
    find ["-q" "-quiet" "--quiet"] a [verbose: false]
    integer? load a [port: load a]
    true [root: to-file a]
]]

;; LIBS
crlf2bin: to binary! join-of crlf crlf
code-map: make map! [200 "OK" 400 "Forbidden" 404 "Not Found"]
mime-map: make map! [
    "css" "text/css"
    "gif" "image/gif"
    "html" "text/html"
    "jpg" "image/jpeg"
    "js" "application/javascript"
    "png" "image/png"
    "r" "text/plain"
    "r3" "text/plain"
    "reb" "text/plain"
]
error-template: trim/auto copy {
    <html><head><title>$code $text</title></head><body><h1>$text</h1>
    <p>Requested URI: <code>$uri</code></p><hr><i>shttpd.r</i> on
    <a href="http://www.rebol.com/rebol3/">REBOL 3</a> $r3</body></html>
}

error-response: func [code uri /local values] [
    values: [code (code) text (code-map/:code) uri (uri) r3 (system/version)]
    reduce [code "text/html" reword error-template compose values]
]

start-response: func [port res /local code text type body] [
    set [code type body] res
    write port ajoin ["HTTP/1.0 " code " " code-map/:code crlf]
    write port ajoin ["Content-type: " type crlf]
    write port ajoin ["Content-length: " length? body crlf]
    write port crlf
    ;; Manual chunking is only necessary because of several bugs in R3's
    ;; networking stack (mainly cc#2098 & cc#2160; in some constellations also
    ;; cc#2103). Once those are fixed, we should directly use R3's internal
    ;; chunking instead: `write port body`.
    port/locals: copy body
]

send-chunk: func [port] [
    ;; Trying to send data >32'000 bytes at once will trigger R3's internal
    ;; chunking (which is buggy, see above). So we cannot use chunks >32'000
    ;; for our manual chunking.
    unless empty? port/locals [write port take/part port/locals 32'000]
]

handle-request: function [config req] [
    parse to-string req [copy method: "get" " " ["/ " | copy uri to " "]]
    uri: default ["index.html"]
    either query: find uri "?" [
        path: copy/part uri query
        query: next query
    ][
        path: copy uri
    ]
    split-path: split path "/"
    parse last split-path [some [thru "."] copy ext: to end (probe type: select mime-map ext)]

    type: default ["application/octet-stream"]
    if verbose [
        print spaced ["======^/action:" method uri]
        print spaced ["path:  " path]
        print spaced ["query: " query]
        print spaced ["type:  " type]
    ]
    if not exists? file: config/root/:path [return error-response 404 uri]
    if error? try [data: read file] [return error-response 400 uri]
    reduce [200 type data]
]

awake-client: func [event /local port res] [
    port: event/port
    switch event/type [
        read [
            either find port/data crlf2bin [
                res: handle-request port/locals/config port/data
                if trap? [start-response port res][
                    print "READ ERROR"
                    close port
                ]
            ] [
                read port
            ]
        ]
        wrote [
            either empty? port/locals [
                close port
            ][
                if trap? [send-chunk port][
                    print "WRITE ERROR"
                    close port
                ]
            ]
        ]
        close [close port]
    ]
]

awake-server: func [event /local client] [
    if event/type = 'accept [
        client: first event/port
        client/awake: :awake-client
        read client
    ]
]

serve: func [web-port web-root /local listen-port] [
    listen-port: open rejoin [tcp://: web-port]
    listen-port/locals: make object! compose/deep [config: [root: (web-root)]]
    listen-port/awake: :awake-server
    if verbose [print spaced [
        "Serving on port" web-port "with root" web-root "..."
    ]]
    wait listen-port
]

;; START

serve port root

;; vim: set sw=4 sts=-1 expandtab:
