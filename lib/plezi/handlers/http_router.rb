module Plezi

	module Base

		#####
		# handles the HTTP Routing
		module HTTPRouter

			class Host
				attr_reader :params
				attr_reader :routes
				def initialize params
					@params = params
					@routes = []
					@params[:assets_public_regex] = /^#{params[:assets_public].to_s.chomp('/')}\//i.freeze
					@params[:assets_public_length] = @params[:assets_public].to_s.chomp('/').length + 1
					@params[:assets_refuse_templates] = /(#{AssetManager.all_extentions.join('|')}|\.\.\/)$/i.freeze
				end
			end

			# return the upgrade handler (the self.on_upgrade method)
			def upgrade_proc
				self.method :on_upgrade
			end
			#handles websocket connection requests.
			def on_upgrade request, response
				host = get_host(request[:host_name].to_s.downcase) || @hosts[:default]
				return false unless host
				request[:host_settings] = host.params
				# return if a route answered the request
				host.routes.each {|r| a = r.on_request(request, response); return a if a}
				# websockets should cut out here
				false
			end
			# initializes the HTTP router (the normal Handler for HTTP requests)
			#
			# the router holds the different hosts and sends them messages/requests.
			@hosts = {}
			@active_host = nil

			# adds a host to the router (or activates an existing host to add new routes). accepts a host name and any parameters not related to the actual connection (ssl etc') (see {Plezi.host})
			def add_host host_name, params = {}
				(params = host_name) && (host_name = params.delete(:host)) if host_name.is_a?(Hash)
				params[:index_file] ||= 'index.html'
				params[:assets_public] ||= '/assets'
				params[:assets_public].chomp! '/'
				params[:public] ||= params[:root] # backwards compatability
				host_name = (host_name.is_a?(String) ? host_name.to_s.downcase : (host_name.is_a?(Regexp) ? host_name : :default))
				@active_host = get_host(host_name) || ( @hosts[host_name] = Host.new(params) )
				add_alias host_name, *params[:alias] if params[:alias] # && host_name != :default
				@active_host
			end
			# adds an alias to an existing host name (normally through the :alias parameter in the `add_host` method).
			def add_alias host_name, *aliases
				host = get_host host_name
				raise "Couldn't find requested host to add alias." unless host
				aliases.each {|a| @hosts[a.to_s.downcase] = host}
				true
			end

			# adds a route to the active host. The active host is the last host referenced by the `add_host`.
			def add_route path, controller, &block
				@active_host ||= add_host :default
				@active_host.routes << ::Plezi::Base::Route.new(path, controller, &block)
			end

			# adds a route to all existing hosts.
			def add_shared_route path, controller, &block
				add_host :default if @hosts.empty?
				@hosts.each {|n, h| h.routes << ::Plezi::Base::Route.new(path, controller, &block) }
			end

			# handles requests send by the HTTP Protocol (HTTPRequest objects)
			def call request, response
				begin
					host = get_host(request[:host_name].to_s.downcase) || @hosts[:default]
					return false unless host
					request[:host_settings] = host.params
					# render any assets?
					return true if render_assets request, response, host.params
					# send static file, if exists and root is set.
					return true if Base::HTTPSender.send_static_file request, response
					# return if a route answered the request
					host.routes.each {|r| a = r.on_request(request, response); return a if a}
					#return error code or 404 not found
					return Base::HTTPSender.send_by_code request, response, 404 unless ( @avoid_404 ||= ( Iodine::Http.on_http == ::Iodine::Http::Rack ? 1 : 0 ) ) == 1
				rescue => e				
					# return 500 internal server error.
					Iodine.error e
					Base::HTTPSender.send_by_code request, response, 500
				end
			end

			# This method attempts to guess at the desired controller's URL, based on it's first path in order of route creation (ignoring host hierarchy).
			#
			# This will be usually used by the Controller's #url_for method to get the relative part of the url.
			def url_for controller, dest, params = {}
				raise TypeError, "Expecting destination parameter to be a Hash" unless dest.is_a?(Hash)
				host = nil
				@hosts.values.each do |h|
					h.routes.each {|r| (host = h) && (controller = r.controller) && break if r.controller && r.controller.ancestors.include?(controller) }
					break if host
				end
				raise "couldn't find Controller's route and host." unless host
				url = []
				dest = dest.dup
				dest.default_proc = Plezi::Base::Helpers::HASH_SYM_PROC
				host.routes.each do |r|
					if r.controller == false
						add = []
						r.url_array.each do |sec|
							next if sec == '*'
							param_name = (::Plezi::Base::Route::REGEXP_OPTIONAL_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_FORMATTED_OPTIONAL_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_REQUIRED_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_FORMATTED_REQUIRED_PARAMS.match(sec))
							param_name = param_name[1].to_sym if param_name

							if param_name && (dest[param_name] || params[param_name])
								add << Plezi::Base::Helpers.encode_url(dest.delete(param_name) || params[param_name])
							elsif !param_name
								add << sec
							else
								add.clear
								next
							end
						end if r.url_array
						url.concat add
					end
					if r.controller == controller
						raise NotImplementedError, "#url_for isn't implemented for this controller's route - could this be a Regexp based or special route?" unless r.url_array
						r.url_array.each do |sec|
							next if sec == '*'
							param_name = (::Plezi::Base::Route::REGEXP_OPTIONAL_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_FORMATTED_OPTIONAL_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_REQUIRED_PARAMS.match(sec) || ::Plezi::Base::Route::REGEXP_FORMATTED_REQUIRED_PARAMS.match(sec))
							param_name = param_name[1].to_sym if param_name
							if param_name && dest[param_name]
								url << Plezi::Base::Helpers.encode_url(dest.delete(param_name))
							elsif !param_name
								url << sec
							elsif ::Plezi::Base::Route::REGEXP_REQUIRED_PARAMS === sec || ::Plezi::Base::Route::REGEXP_OPTIONAL_PARAMS === sec
								url << ''.freeze
							elsif ::Plezi::Base::Route::REGEXP_FORMATTED_REQUIRED_PARAMS === sec
								raise ArgumentError, "URL can't be formatted becuse a required parameter (#{param_name.to_s}) isn't specified and it requires a special format (#{::Plezi::Base::Route::REGEXP_FORMATTED_REQUIRED_PARAMS.match(sec)[2]})."
							end
						end
						return "/#{url.join '/'.freeze}#{"?#{dest.map {|k,v| "#{Plezi::Base::Helpers.encode_url k}=#{Plezi::Base::Helpers.encode_url v}" } .join('&'.freeze)}" if dest.any?}" 
					end
				end
				false
			end

			protected

			def get_host host_name
				@hosts.each {|k, v| return v if k === host_name}
				nil
			end

			###############
			## asset rendering and responses

			# renders assets, if necessary, and places the rendered result in the cache and in the public folder.
			def render_assets request, response, params
				# contine only if assets are defined and called for
				return false unless params[:assets] && (request.path =~ params[:assets_public_regex])
				# review callback, if defined
				return true if params[:assets_callback] && params[:assets_callback].call(request, response)

				# get file requested
				source_file = File.join(params[:assets], *(request.path[params[:assets_public_length]..-1].split('/')))


				# stop if file name is reserved / has security issues
				return false if File.directory?(source_file) || source_file =~ params[:assets_refuse_templates]

				# set where to store the rendered asset
				target_file = File.join( params[:public].to_s, *request.path.split('/') )

				# send the file if it exists (no render needed)
				if File.exists?(source_file)
					data = if ::Plezi::Cache::CACHABLE.include?(::File.extname(source_file)[1..-1])
						Plezi.cache_needs_update?(source_file) ? Plezi.save_file(target_file, Plezi.reload_file(source_file), (params[:public] && params[:save_assets])) : Plezi.load_file(source_file)
					else
						::File.new source_file, 'rb'
					end
					return (data ? Base::HTTPSender.send_raw_data(request, response, data, MimeTypeHelper::MIME_DICTIONARY[::File.extname(source_file)]) : false)
				end

				# render the file if it's a registered asset
				data = ::Plezi::AssetManager.render source_file, binding
				if data
					return ::Plezi::Base::HTTPSender.send_raw_data request, response, Plezi.save_file(target_file, data, (params[:public] && params[:save_assets])), MimeTypeHelper::MIME_DICTIONARY[::File.extname(source_file)]
				end

				# send the data if it's a cached asset (map files and similar assets that were cached while rendering)
				if Plezi.cached?(source_file)
					return Base::HTTPSender.send_raw_data(request, response, Plezi.get_cached(source_file), MimeTypeHelper::MIME_DICTIONARY[::File.extname(source_file)])
				end

				# return false if an asset couldn't be rendered and wasn't found.
				return false
			end
			extend self
		end
		Iodine::Http.on_http ::Plezi::Base::HTTPRouter
		Iodine::Http.on_websocket ::Plezi::Base::HTTPRouter.upgrade_proc
	end
end
