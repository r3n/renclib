Rebol [
  author: 'Graham
  date: 2-May-2021
]

repo: lowercase ask "github/gitlab?"
user: ask "Userid?"
project: ask "Your project?"

if any [ empty? repo empty? user empty? project][
  unset [repo user project]
  quit
]

file: _
idx: %index.reb

case  [
  repo = "github" [
    if 1 < length of result: split project "/" [
      parse project [thru "/" copy temp to end] 
      idx: unspaced [temp "/" idx]
      project: first result
    ]
    file: to url!  unspaced [https://github.com/ user "/" project "/blob/master/" idx]
    ; unset [repo user project idx temp]
    repo: user: project: idx: temp: ~unset~
    if error? trap [
      do file
      print ["Your userfile (file) is at: " file]
    ][
      print "Repository not found.  Check userid, and repo name."
    ]
  ]
  repo = "gitlab" [
    if 1 < length of result: split project "/" [
      parse project [thru "/" copy temp to end] 
      idx: unspaced [temp "/" idx]
      project: first result
    ]
    file: to url!  unspaced [https://gitlab.com/ user "/" project "/-/blob/master/" idx]
    ; unset [repo user project idx temp]
    repo: user: project: idx: temp: ~unset~
    if error? trap [
      do file
      print ["Your userfile (file) is at: " file]
    ][
      print "Repository not found.  Check userid, and repo name."
    ]
  ]
  true [print "repo not found" quit]
]
