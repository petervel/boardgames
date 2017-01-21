exports.render = !->
	pageName = Page.state.get(0)
	#return renderRankingsPage() if pageName is 'rankings'
	return renderGamePage(+pageName) if pageName
	renderGames()


renderGames = !->
	Dom.div !->
		Dom.style position: 'relative'

		Dom.div !->
			Dom.style Box: 'horizontal middle'
			myForm = Form.input {text: 'Enter BGG id here'}
			Ui.button "Add", !->
				Server.call 'addGame', myForm.value()
				myForm.value('')

		Db.shared.iterate 'games', (game) !->
			return unless game.get('name')
			Ui.item !->
				Dom.style Box: 'horizontal middle'
				Dom.div !->
					Dom.style
						width: '50px'
						height: '30px'
						margin: '0 10px'
						borderRadius: '3px'
						background: "transparent url(#{game.get('thumbnail')}) no-repeat center center"
						backgroundSize: 'contain'
				Dom.div !->
					Dom.style Flex: 1
					Dom.text "#{game.get('name')} (#{game.get('yearpublished')})"

				sum = Obs.create 0
				count = Obs.create 0
				Dom.div !->
					game.iterate 'ratings', (rating) !->
						thisRating = +rating.get()
						sum.incr thisRating
						count.incr()
						Obs.onClean !->
							count.incr -1
							sum.incr -thisRating

					if sum.get()
						Icon.render
							data: 'star'
							size: '25'
							color: '#ffaa00'
						Dom.text Math.round(10*sum.get()/count.get())/10

				Dom.onTap !-> Page.nav game.key()
		, (game) -> -game.get('addedTime')

renderGamePage = (gameId) !->
	game = Db.shared.ref 'games', gameId

	if thumbnail = game.get 'thumbnail'
		hiRes = Obs.create()
		Dom.div !->
			Dom.style margin: '0', display: 'block', height: '80%', maxHeight: '200px'
			imgUrl = hiRes.get() ? thumbnail
			Dom.style backgroundImage: "url(#{imgUrl})", backgroundSize: 'cover', backgroundPosition: 'center'
			unless hiRes.get()?
				Dom.onTap !-> if image = game.get 'image' then hiRes.set image

	Dom.div !->
		Dom.style width: '90%', margin: '20px auto', position: 'relative'

		Dom.h1 !->
			Dom.style textAlign: 'center'
			Dom.text game.get 'name'

		Dom.p !->
			Dom.style maxHeight: '100px', margin: '20px 0', overflow: 'auto'
			Dom.text game.get 'description'

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
			Dom.style margin: '30px auto'

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
