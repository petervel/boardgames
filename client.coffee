exports.render = !->
	pageName = Page.state.get(0)
	#return renderRankingsPage() if pageName is 'rankings'
	return renderGamePage(+pageName) if pageName
	renderGames()


renderGames = !->
	Dom.div !->
		Dom.style Box: 'horizontal middle', width: '100%'
		myForm = Form.input {text: 'Enter BGG id here'}
		Ui.button "Add", !-> Server.call 'addGame', myForm.value()

	Db.shared.iterate 'games', (game) !->
		Ui.item !->
			Dom.style Box: 'horizontal middle'
			Dom.div !->
				Dom.img !->
					Dom.style width: '50px', margin: '0 10px', borderRadius: '3px'
					Dom.prop 'src', game.get('thumbnail')
			Dom.div !->
				Dom.style Flex: 1
				Dom.text "#{game.get('name')} (#{game.get('yearpublished')})"

			sum = Obs.create 0
			count = Obs.create 0
			Dom.div !->
				game.iterate 'ratings', (rating) !->
					sum.incr +rating.get()
					count.incr()

				if sum.get()
					Icon.render
						data: 'star'
						size: '25'
						color: '#ffaa00'
					Dom.text sum.get()/count.get()

			Dom.onTap !-> Page.nav game.key()

renderGamePage = (gameId) !->
	game = Db.shared.ref 'games', gameId

	Dom.h1 !->
		Dom.text game.get 'name'

	if image = game.get 'image'
		Dom.div !->
			Dom.style margin: '20px auto', display: 'block', width: '80%', height: '80%', maxHeight: '140px'
			Dom.style backgroundImage: "url(#{image})", backgroundSize: 'cover', backgroundPosition: 'center'

	showStar = (nr, vote, ours=false) !->
		Dom.span !->
			Icon.render
				data: if not vote? or nr > vote then 'star-outline' else 'star'
				size: '25'
				color: if not vote? then '#ccc' else '#ffaa00'
				onTap: !->
					return unless ours
					Server.sync 'rateGame', gameId, nr, !->
						game.set 'ratings', App.userId(), nr

	Dom.div !->
		Dom.style Box: 'horizontal middle', _justifyContent: 'space-around'
		Dom.div !-> Dom.text "Jouw beoordeling:"
		Dom.div !->
			vote = game.get 'ratings', App.userId()
			for i in [1..5]
				showStar i, vote, true

	Dom.div !->
		Dom.style width: '80%', margin: '30px auto'

		foundOthers = Obs.create false
		Dom.div !->
			return unless foundOthers.get()
			Dom.style margin: '10px 0'
			Dom.text "Andere beoordelingen:"
		game.iterate 'ratings', (rating) !->
			userId = +rating.key()
			return if userId is App.userId() or App.userIsMock userId
			foundOthers.set true
			Dom.div !->
				Dom.style Box: 'horizontal middle'
				Ui.avatar
					key: App.userAvatar userId
					onTap: !-> App.showMemberInfo userId

				Dom.div !->
					Dom.style Flex: 1, marginLeft: '10px'
					Dom.text App.userName userId

				Dom.div !->
					for i in [1..5]
						showStar i, rating.get()
