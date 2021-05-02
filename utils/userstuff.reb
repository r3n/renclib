Rebol []

repo: lowercase ask "github/gitlab?"
user: ask "Userid?"
project: ask "Your project?"

if any [ empty? repo empty? user empty? project][quit]

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
   ]
  repo = "gitlab" [file: to url! unspaced [https://gitlab.com/ user "/" project "/-/blob/master/" idx]]
  true [print "repo not found" quit]
]

print ["Your userfile (file) is at: " file]
