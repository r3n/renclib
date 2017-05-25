rebol [
	file: %changes.reb
	notes: {to find the discourse post that contains a given hash in the change-log topic 54}
	date: 26-May-2017
	author: "Graham"
]

changes*: function [
	{browse to specific post by hash where search is limited to limit posts}
	discourse [url!] topic_id [integer!] hash [string!] limit [integer!]
][
	unless set? 'load-json [
		import <json>
	]
	j: load-json to string! read rejoin [discourse topic_id %.json]
	posts: copy/part reverse select select j 'post_stream 'stream limit
	request: collect [
		for-each id posts [
			if integer? id [
				keep ajoin ["post_ids[]=" id "&"]
			]
		]
	]
	; remove the last &
	take/last request
	j: load-json to string! read rejoin [discourse topic_id "/posts.json?" ajoin request]
	posts: select select j 'post_stream 'posts
	for-each map posts [
		cooked: select map 'cooked
		parse cooked [thru {<strong>Commit</strong>} thru "<" thru ">" copy thishash to </a>]
		if thishash = hash [
			id: select map 'id 
			browse rejoin [discourse topic_id "/" id]
			return _
		]
	]
	return "Commit not found.  Expand limit"
]

reb-changes: func [hash][
	changes* http://rebolchat.me/t/ 54 hash 10
]

reb-changes rebol/commit
