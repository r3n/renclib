Rebol [
    title: "Work-in-Progress Ren-C variant of Rebol JSON Parser by @rgchris"
    file: %json.reb
    purpose: "Convert a Rebol block to a JSON string"
    rights: http://opensource.org/licenses/Apache-2.0
    type: module
    name: json
    exports: [load-json to-json]
    notes: --[
        Derived from code by @rgchris:
        http://www.ross-gill.com/page/JSON_and_Rebol

        The implementation method used series switching in PARSE as well as mutating
        the input series, which presents challenges for Ren-C, so there are problems.

        Discussion of further directions here:
        https://rebol.metaeducation.com/t/json-and-rebol/2562
    ]--
]

; Old definition of OK? (temporary, should rewrite parse rules)
ok?: cascade [error?/ not/]

load-json: use [
    tree branch here val is-flat emit new-child to-parent neaten word to-word
    space comma number string block object _content value ident
][
    branch: make block! 10

    emit: func [val][here: insert here val]
    new-child: [(insert branch insert here here: make block! 10)]
    to-parent: [(here: take branch)]
    neaten: [
        (new-line:all head here 'yes)
        (new-line:all:skip head here 'yes 2)
    ]

    to-word: use [word1 word+][
        ; upper ranges borrowed from AltXML
        word1: charset [
            "!&*=?ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz|~"
            #"^(C0)" - #"^(D6)" #"^(D8)" - #"^(F6)" #"^(F8)" - #"^(02FF)"
            #"^(0370)" - #"^(037D)" #"^(037F)" - #"^(1FFF)" #"^(200C)" - #"^(200D)"
            #"^(2070)" - #"^(218F)" #"^(2C00)" - #"^(2FEF)" #"^(3001)" - #"^(D7FF)"
            #"^(f900)" - #"^(FDCF)" #"^(FDF0)" - #"^(FFFD)"
        ]

        word+: charset [
            "!&'*+-.0123456789=?ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz|~"
            #"^(B7)" #"^(C0)" - #"^(D6)" #"^(D8)" - #"^(F6)" #"^(F8)" - #"^(037D)"
            #"^(037F)" - #"^(1FFF)" #"^(200C)" - #"^(200D)" #"^(203F)" - #"^(2040)"
            #"^(2070)" - #"^(218F)" #"^(2C00)" - #"^(2FEF)" #"^(3001)" - #"^(D7FF)"
            #"^(f900)" - #"^(FDCF)" #"^(FDF0)" - #"^(FFFD)"
        ]

        lambda [val [text!]][
            all [
                ok? parse val [word1 opt some word+]
                to word! val
            ]
        ]
    ]

    space: use [space][
        space: charset " ^-^/^M"
        [opt some space]
    ]

    comma: [space #"," space]

    number: use [dg ex nm as-num][
        dg: charset "0123456789"
        ex: [[#"e" | #"E"] opt [#"+" | #"-"] some dg]
        nm: [opt #"-" some dg opt [#"." some dg] opt ex]

        as-num: lambda [val [text!]][
            case [
                not ok? parse val [opt "-" some dg][to decimal! val]
                error? val: to integer! val [to rune! val]
                val [val]
            ]
        ]

        [val: across nm (val: as-num val)]
    ]

    string: use [ch es hx mp decode][
        ch: complement charset --[\"]--
        es: charset --["\/bfnrt]--
        hx: charset "0123456789ABCDEFabcdef"
        mp: [#"^"" "^"" #"\" "\" #"/" "/" #"b" "^H" #"f" "^L" #"r" "^M" #"n" "^/" #"t" "^-"]

        decode: use [ch mk escape][
            escape: [
                ; should be possible to use CHANGE keyword to replace escaped characters.
                mk: <here>, #"\" [
                    es (mk: change:part mk select mp mk.2 2)
                    |
                    #"u" ch: across repeat 4 hx (
                        mk: change:part mk codepoint-to-char to-integer:unsigned debase:base ch 16 6
                    )
                ] seek (mk)
            ]

            lambda [text [<opt> text!]][
                either not text [make text! 0][
                    all [ok? parse text [opt some [to "\" escape] to <end>], text]
                ]
            ]
        ]

        [#"^"" val: across [opt some [some ch | #"\" [#"u" repeat 4 hx | es]]] #"^"" (val: decode val)]
    ]

    block: use [list][
        list: [space opt [value opt some [comma value]] space]

        [#"[" new-child list #"]" neaten.1 to-parent]
    ]

    _content: [#"{" space -["_content"]- space #":" space value space "}"] ; Flickr

    object: use [name list as-map][
        name: [
            string space #":" space (
                emit either is-flat [
                    to tag! val
                ][
                    any [
                        to-word val
                        lock val
                    ]
                ]
            )
        ]
        list: [space opt [name value opt some [comma name value]] space]
        as-map: [(if not is-flat [here: change back here make map! pick back here 1])]

        [#"{" new-child list #"}" neaten.2 to-parent as-map]
    ]

    ident: use [initial ident][
        initial: charset ["$_" #"a" - #"z" #"A" - #"Z"]
        ident: union initial charset [#"0" - #"9"]

        [initial opt some ident]
    ]

    value: [
          "null" (emit '~null~)
        | "true" (emit 'true)
        | "false" (emit 'false)
        | number (emit val)
        | string (emit val)
        | _content
        | object | block
    ]

    func [
        "Convert a JSON string to Rebol data"
        json [text! blob! file! url!] "JSON string"
        :flat "Objects are imported as tag-value pairs"
        :padded "Loads JSON data wrapped in a JSONP envelope"
    ][
        case:all [
            match [url! file!] json [
                json: read:string (json)
            ]
            blob? json [json: to text! json]
        ]

        is-flat: flat
        tree: here: make block! 0

        either ok? parse json either padded [
            [space ident space "(" space opt value space ")" opt ";" space]
        ][
            [space opt value space]
        ][
            pick tree 1
        ][
            panic "Not a valid JSON string"
        ]
    ]
]

to-json: use [
    json emit emits escape emit-rune emit-date
    here lookup comma block object block-of-pairs value
][
    emit: func [data][
        append json (non block! data else [spread reduce data])
    ]
    emits: func [data][emit -["]- emit data emit -["]-]

    escape: use [mp ch encode][
        mp: [#"^/" "\n" #"^M" "\r" #"^-" "\t" #"^"" "\^"" #"\" "\\" #"/" "\/"]
        ch: intersect ch: charset [#" " - #"~"] difference ch charset extract mp 2

        encode: lambda [here][
            change:part here any [
                select mp here.1
                unspaced ["\u" skip tail of form to-hex codepoint of here.1 -4] ; to integer!
            ] 1
        ]

        func [txt][
            parse txt [
                opt some [txt: <here> some ch | one (txt: encode txt) seek (txt)]  ; !!! series-switching
            ]
            return head of txt
        ]
    ]

    emit-rune: use [dg nm mk][
        dg: charset "0123456789"
        nm: [opt "-" some dg]

        [(either ok? parse next form here.1 [mk: across nm][emit mk][emits here.1])]
    ]

    emit-date: use [pad second][  ; converts date! to RFC 3339 Date String
        pad: func [part length][
            part: to text! part
            return head of insert:dup part "0" length - length? part
        ]

        the (
            emits unspaced collect [
                keep spread reduce [pad here.1.year 4 "-" pad here.1.month 2 "-" pad here.1.day 2]
                if here.1.time [
                    keep spread reduce ["T" pad here.1.hour 2 ":" pad here.1.minute 2 ":"]
                    keep either integer? here.1.second [
                        pad here.1.second 2
                    ][
                        second: split to text! here.1.second "."
                        spread reduce [pad second.1 2 "." second.2]
                    ]
                    keep either any [
                        null? here.1.zone
                        zero? here.1.zone
                    ]["Z"][
                        reduce [
                            either here.1.zone.hour < 0 ["-"]["+"]
                            pad abs here.1.zone.hour 2 ":" pad here.1.zone.minute 2
                        ]
                    ]
                ]
            ]
        )
    ]

    lookup: [
        here: <here> match [@word! @path!]
        (change here reduce reduce [here.1])
        ahead '<fail>  ; no FAIL combinator in UPARSE, yet
    ]

    comma: [(if not tail? here [emit ","])]

    block: [
        (emit "[") opt some [here: <here> value here: <here> comma] (emit "]")
    ]

    block-of-pairs: [
          some [set-word?/ one]
        | some [tag! one]
    ]

    object: [
        (emit "{")
        opt some [
            here: <here> [
                set-word?/ (change here unchain here.1) | any-string?/
            ]
            (emit [-["]- escape to text! here.1 -[":]-])
            here: <here> value here: <here> comma
        ]
        (emit "}")
    ]

    value: [
          lookup ; resolve an @WORD! or @PATH! reference
        | any-number?/ (emit here.1)
        | ['true | 'false] (emit to text! here.1)
        | ['~null~] (emit the null)
        | date! emit-date
        | rune! emit-rune
        | [
            any-string?/ | word! | lit-word?/ | tuple! | pair! | money! | time!
        ] (emits escape form here.1)
        | word! (emits escape form here.1)

        | [object! | map!] seek (here) (
            ;
            ; !!! This was `change here body-of first here`.  BODY-OF was a
            ; sketchy idea for objects in the first place, but in particular
            ; with the addition of nulls.  This does a workaround to try and
            ; keep the tests in PatientDB working--but a better theory of
            ; JSON interoperability is needed.
            ;
            change here map-each [key value] (first here) [
                spread reduce [
                    setify key
                    case [
                        null? value ['null]
                        ; there is no #[true] or #[false], just words
                        ; to be compatible with JSON, use the words and TRUE?/FALSE?
                        <else> [value]
                    ]
                ]
            ]
        ) into object
        | into block-of-pairs seek (here) (change here copy first here) into object
        | any-list?/ seek (here) (change here copy first here) into block

        | any-value?/ (emits to tag! type of first here)
    ]

    lambda [data][
        json: make text! 1024
        all [
            ok? parse compose [(data)][here: <here>, value]
            json
        ]
    ]
]
