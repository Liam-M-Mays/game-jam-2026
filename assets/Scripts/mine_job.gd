extends joob

var res : resource

func execute(ref : Node):
	ref.is_mining = true
	ref.to_mine = res
	ref.target = res.position
