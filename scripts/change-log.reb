Rebol [
    title: "Github Change Log for Discourse"
    file: %change-log.reb
    notes: {Creates a change log on a discourse site for the GitHub commits and links to S3 deployed binaries}
    author: "Graham Chiu"
    versioni: 0.0.2
    date: 20-May-2017
    help: http://chat.stackoverflow.com/rooms/291/rebol
]

system/options/dump-size: 1000 ; just for debugging variables and payloads

import <json>
import <xml>
import <webform>

last-hash: %metaeducation-renc.reb
s3files: http://metaeducation.s3.amazonaws.com
commits: https://api.github.com/repos/metaeducation/ren-c/commits
discourse-user: "rebolbot"
discourse-api-key: "get-this-from-admin-who-will-give-you-a-user-specific-api-key"
discourse-post-url: rejoin [
    http://www.rebolchat.me/posts.json?api_key=
    discourse-api-key
    "&api_username=" discourse-user
]
root: http://metaeducation.s3.amazonaws.com/travis-builds/

topid_id: 54
category: 6

; get all the unique commit values still available for download
dom: load-xml/dom to string! read s3files
result: dom/get <Contents>

compose-message: function [message [string!] date [date! string!]][
    dump date
    dump message
    if date? date [
        date: ajoin [date/year "-" next form 100 + date/month "-" next form 100 + date/day ]
    ]
    return to-json make map! compose copy [
        title "Change log"
        topic_id (topic_id)
        raw (message)
        category (category)
        name (discourse-user)
        color "49d9e9"
        text_color "f0fcfd"
        created_at (date)
    ]
]

files: copy []

for-each [key value] result/position [
    ; r: copy value
    if parse value [
        path! set keyvalue string!
        path! set datestring string!
        to end
    ][
        if parse keyvalue ["travis-builds/" copy os: to "/" "/" copy filename to end][
            if parse filename ["r3-" [copy hash: to "-" to end | copy hash: to end]][
                append files hash
                repend/only files [os filename]
            ]
        ]
    ]
]

if empty? files [quit]

operating-systems: [
    "0.13.2" "Android5-arm" 
    "0.2.40" "OSX x64" 
    "0.3.1" "Win32 x86" 
    "0.3.40" "Win64 x86" 
    "0.4.4" "Linux32 x86" 
    "0.4.40" "Linux64 x86" 
] 

; now read the commits
json: reverse load-json to-string read commits ;=> block

post-commit: function [content [string!] date][
    content: compose-message content date
    write discourse-post-url compose [headers POST [Content-Type: "application/json"] (content)]
]

start: 0

; set this to true if first ren, or when we pass the previous posted hash
okay2post: false
if blank? done-hash: attempt [load last-hash] [
    okay2post: true
]

for-each committed json [ ; map!
    if something? hash: select committed 'sha [
        ++ start
        ; we have a block of shortened hashes
        print newline
        print/only "Date: " print date: select select select committed 'commit 'author 'date
        print/only "Author: " print author: select select select committed 'commit 'author 'name
        print/only "Message: " print message: select select committed 'commit 'message
        print/only "Commit: " print html_url: select committed 'html_url
        html_url: ajoin [ "[" hash "](" html_url ")"]
        dump hash
        print "^/Binaries available?"
        binaries: copy []
        for-each [h block] files [
            if find hash h [
                append binaries block
            ]
        ]
        content: copy 
{**Date**: $1
**Author**: $2
**Commit**: $4
**Message**: $3
}
        postcontent: reword content compose copy [1 (date) 2 (author) 3 (message) 4 (html_url)]
        current-os: copy ""
        unless empty? binaries [
            append postcontent newline
            append postcontent "_The binaries below are only available for a couple of weeks or so after commit date._^/" 
            for-each [os file] binaries [
                if current-os <> os [
                    current-os: copy os
                    repend postcontent [newline os " " select operating-systems os newline]
                ]
                ; http://metaeducation.s3.amazonaws.com/travis-builds/0.13.2/r3-d503c1d
                print filepath: ajoin [ "[" file "](" root os "/" file ")"]
                append postcontent ajoin [filepath newline]
            ]
        ]
        if error? err: trap [
            if okay2post [
                print "Posting message ..."
                post-commit postcontent date 
                ;probe postcontent
                save/all last-hash hash
                sleep 60 ; there's anti-flooding
            ]
            if hash = done-hash [
                ; we have reached the last posted hash, so now set to post, and start saving new hash
                okay2post: true
            ]
        ][
            probe err
            halt
        ]
    ]
 ]
