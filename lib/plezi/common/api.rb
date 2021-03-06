
module Plezi

	module_function

	# Defines methods used to set up the Plezi app.

	# Deprecated. use {Plezi.host}.
	def listen parameters = {}
		Iodine.warn "listen is deprecated. use `Plezi.host` instead."
		host parameters.delete(:host) || :default, parameters
	end

	# adds a route to the last server created
	def route(path, controller = nil, &block)
		if controller == :client
			client_path = File.expand_path(File.join('..','..','..','..','resources','plezi_client.js'), __FILE__)
			controller = nil
			block = Proc.new {  Plezi.cache_needs_update?(client_path) ? Plezi.reload_file(client_path) : Plezi.load_file(client_path) }
		end
		::Plezi::Base::HTTPRouter.add_route path, controller, &block
	end


	# adds a shared route to all existing services and hosts.
	def shared_route(path, controller = nil, &block)
		::Plezi::Base::HTTPRouter.add_shared_route path, controller, &block
	end

	# public API to add or setup domain names related to the application.
	#
	# A default host can be created or accessed by using `:default` of false for the host name.
	#
	# Accepts:
	# host_name:: (optional, can be omitted) the name (domain name) of the host as a String object. Use the Symbol `:default` for the catch-all domain name.
	# options_hash:: see further detail.
	# 
	#
	# The options is a Hash object with any of the following options (Hash keys):
	# host:: the ost name to be used if one isn't supplied as a direct argument. Defaults to the `:default` host.
	# alias:: a String or an Array of Strings which represent alternative host names (i.e. `alias: ["admin.google.com", "admin.gmail.com"]`).
	# public:: the public root folder. if this is defined, static files will be served from this folder and all it's sub-folders. Plezi does NOT support file indexing.
	# assets:: the assets root folder. defaults to nil (no assets support). if the path is defined, assets will be served from `/assets/...` (or the public_asset path defined) before any static files. assets will not be served if the file in the /public/assets folder if up to date (a rendering attempt will be made for systems that allow file writing).
	# assets_public:: the assets public uri location (uri format, NOT a file path). defaults to `/assets`. `save_assets` will set if assets should be saved to the assets public folder as static files (defaults to false).
	# assets_callback:: a method that accepts two parameters: (request, response) and renders any custom assets. the method should return `false` unless it had set the response.
	# save_assets:: saves the rendered assets to the filesystem, under the public folder. defaults to false.
	# templates:: the templates root folder. defaults to nil (no template support). templates can be rendered by a Controller class, using the `render` method.
	#
	# Assets:
	#
	# Assets support will render `.sass`, `.scss` and `.coffee` and save them as local files (`.css`, `.css`, and `.js` respectively)
	# before sending them as static files.
	#
	# Should you need to render a different type of asset, you can define an assets_callback (or submit a pull request with a patch). 
	# 
	# templates:
	#
	# Plezi's controller.render ERB, Slim and Haml are natively supported.
	#
	# @return [::Plezi::Base::HTTPRouter]
	#
	def host(host_name, params = {})
		::Plezi::Base::HTTPRouter.add_host host_name, params
	end

	# This allows you to use the Plezi framework's code inside your existing Rack application - WITHOUT running the actual server.
	#
	# The server will not be initiatet and instead you will be able to use Plezi controllers and the Redis auto-config
	# to broadcast Plezi messages to other Plezi processes - allowing for scalable intigration of Plezi into existing Rack applications.
	def start_placebo receiver = nil
		# force start Iodine only if Iodine isn't used as the server
		if ::Iodine.protocol == ::Iodine::Http::Http1 && (defined?(::Rack::VERSION) ? (::Rack::Handler.default == ::Iodine::Http::Rack rescue true) : true)
			Iodine.log("* `start_placebo` Placebo directive ignored, as this seems to be the main application.\n")
			# just initialize the receiver class (no instance) and return
			Plezi::Placebo.new(receiver, false) if receiver
			return false
		end
		unless @placebo_initialized
			raise "Placebo fatal error: Redis connection failed to load - make sure gem is required and `ENV['PL_REDIS_URL']` is set." unless redis # make sure the redis connection is activated
			Iodine.log "* Plezi #{Plezi::VERSION} Services will start with no Server - This is the Placebo application\n"
			::Iodine.protocol = :no_server
			Iodine.force_start!
			@placebo_initialized = true
		end
		receiver ? Plezi::Placebo.new(receiver) : true
	end

	# deprecation notice
	def start_rack
		Iodine.warn "`start_rack` is deprecated. There is no need to call this method."
	end
end