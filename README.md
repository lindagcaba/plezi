# [<img src='https://raw.githubusercontent.com/boazsegev/plezi/master/logo/dark.png' alt='Plezi' style='width:20em;' />](http://www.plezi.io)

[![Gem Version](https://badge.fury.io/rb/plezi.svg)](http://badge.fury.io/rb/plezi)
[![Inline docs](http://inch-ci.org/github/boazsegev/plezi.svg?branch=master)](http://www.rubydoc.info/github/boazsegev/plezi/master)
[![GitHub](https://img.shields.io/badge/GitHub-Open%20Source-blue.svg)](https://github.com/boazsegev/plezi)

## Special notice - pre version 13

One of the best compliments Plezi keeps receiving is the feedback about how easy it is to set up a websocket application using Plezi.

On the other hand, Plezi's server, Iodine 0.1.x was written in Ruby and allowed a very fast and easy development...

...but with time and experience we all discovered the Ruby's `select` was limited to ~1024 connections, and that Plezi developers wanted more - more connections, more performance, more ease of deployment and more integration with Rails/Sinatra.

I'm working very hard on rewriting the core server in C. Iodine 0.2.x is written in C and it supports only Unix based systems with `kqueue` or `epoll` support (BSD/Linux/MacOSX).

This means that if your machine has the memory and the resources (open file descriptor limits apply), Iodine could support tens of thousands of concurrent connections.

Also, a lot of the API is changing for better integration with Rack based frameworks (Rails/Sinatra).

This also means that some sacrifices will be made. i.e. more Rack integration means that we loose HTTP streaming (Rack's specifications have their limits).

This is where you come in. **Now** is the time to push those changes you wanted to integrate into Plezi. Send in your thoughts and feedback. You can open an issue or email me. Just write about how you use Plezi and what features you think are super important to keep and which once bother you.

Even if I cannot answer everyone, it will all go into the next version's design and I'll do my best.

## Plezi

Plezi is a Ruby framework for realtime web applications. It's name comes from the word "pleasure", since Plezi is a pleasure to work with.

With Plezi, you can easily:

1. Create a Ruby web application, taking full advantage of RESTful routing, HTTP streaming and scalable Websocket features;

2. Add Websocket services and RESTful HTTP Streaming to your existing Web-App, (Rails/Sinatra or any other Rack based Ruby app);

3. Create an easily scalable backend for your SPA.

## Guides and documentation

You can find [tutorials and guides at Plezi.io](http://www.plezi.io/docs).

Plezi leverages Ruby's mixins and meta-programming, so the YARD documentation is hard to navigate... I started writing guides for Plezi and would really appreciate any help you can offer.

Please feel free to [contribute to Plezi's guides](https://github.com/boazsegev/plezi-website), or even just observe the [plezi.io website's code](https://github.com/boazsegev/plezi-website) (implemented using Plezi).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'plezi'
```

Or install it yourself as:

    $ gem install plezi

## Quick start

Plezi is super easy. Please read our [Getting Started guide](http://www.plezi.io/docs/basics) for more information.

Here's a super quick intro:

### A running start

Get a jump start by typing (in your terminal):

    $ plezi mini appname
OR
    $ plezi new appname

Next, simply double click the `appname` script file to start the server. Or, from the terminal:

    $ cd appname
    $ ruby ./appname

See it work: [http://localhost:3000/](http://localhost:3000/)

### Hello world

The Plezi framework was designed with intuitive ease of use in mind.

Open the `irb` terminal and type:

    require 'plezi'
    route('*') { "Hello World!" }
    exit # <- this exits the terminal and starts the server

A Hello World web application using three lines of code (one line is the actual code)... see it at [localhost:3000](http://localhost:3000/).

### Hello Object Oriented design

Plezi really shines when we use Controller classes. Try this in your `irb` terminal:

    require 'plezi'
    class MyDemo
        # the index will answer '/'
        def index
            "Hello World!"
        end
        # a regular method will answer it's own name i.e. '/foo'
        def foo
            "Bar!"
        end
        # show is RESTful, it will answer any request looking like: '/(:id)'
        def show
            "Are you looking for: #{params[:id]}?"
        end
    end

    route '/', MyDemo
    exit

Now visit [index](http://localhost:3000/) and [foo](http://localhost:3000/foo) or request an id, i.e. [http://localhost:3000/1](http://localhost:3000/1).

### Quick, websockets!

Plezi was designed for websockets from the ground up. If your controller class defines an `on_message(data)` callback, plezi will automatically enable websocket connections for that route.

Here's a Websocket echo server using Plezi:

    require 'plezi'
    class MyDemo
        def on_message data
            # sanitize the data and write it to the websocket.
            write ">> #{ERB::Util.html_escape data}"
        end
    end

    route '/', MyDemo
    exit

Each controller is also a "channel" which can broadcast to everyone who's connected to it.

Here's a websocket chat-room server using Plezi, comeplete with minor authentication (requires a chat handle):

    require 'plezi'
    class MyDemo
        def on_open
            close unless params[:id]
        end
        def on_message data
            # broadcast to everyone else (NOT ourselves):
            broadcast :chat_message,  "#{params[:id]}: #{data}"
            # write to our own websocket:
            chat_message "Me: #{data}"
        end
        protected
        # implement the broadcast event
        def chat_message data
            write ERB::Util.html_escape(data)
        end
    end

    route '/', MyDemo
    # You can connect to this chatroom by going to ws://localhost:3000/any_nickname
    # but you need to write a websocket client too...
    # try two browsers with the client provided by http://www.websocket.org/echo.html
    exit

Broadcasting isn't the only tool Plezi offers, we can also send a message to a specific connection using `unicast`, or send a message to everyone (no matter what controller is handling their connection) using `multicast`...

...It's even possible to register a unique identity, such as a specific user or even a `session.id`, so their messages are waiting for them even when they're off-line (you decide how long they wait)! We simply use `register_as @user.id` in our `on_open` callback, and than the user can get notifications sent by `notify user.id, :evet_method, *args`.

### Scaling? easy!

Scale your Websocket application with one line of code:

    # REDIS_URL is where Heroku-Redis stores it's URL
    ENV['PL_REDIS_URL'] ||= ENV['REDIS_URL'] || "redis://:password@my.host:6389/0"

Websocket messages (broadcasts, unicasts, etc') and even session data (Plezi keeps it away from the client) will now sync using Redis throughout all your server instances.


### Hosts, template rendering, assets...?

Plezi allows us to use different host-names for different routes. i.e.:

    require 'plezi'

    host # this is the default host, it's always last to be checked.
    route('/') {"this is localhost"}

    host host: '127.0.0.1' # special host, for the IP name
    route('/') {"this is only for the IP!"}
    exit

Each host has it's own settings for a public folder, asset rendering, templates etc'. For example:

    require 'plezi'

    class MyDemo
        def index
            # to make this work, create a template and set the correct template folder
            render :index
        end
    end

    host public: File.join('my', 'public', 'folder'),
        templates: File.join('my', 'templates', 'folder'),
        assets: File.join('my', 'assets', 'folder')

    route '/', MyDemo
    exit

Plezi supports ERB (i.e. `template.html.erb`), Slim (i.e. `template.html.slim`), Haml (i.e. `template.html.haml`), CoffeeScript (i.e. `asset.js.coffee`) and Sass (i.e. `asset.css.scss`) right out of the box... and it's even extendible using the `Plezi::Renderer.register` and `Plezi::AssetManager.register`


## Longer version - Plezi Controller classes

One of the best things about the Plezi is it's ability to take in any class as a controller class and route to the classes methods with special support for RESTful methods (`index`, `show`, `new`, `save`, `update`, `delete`, `before` and `after`) and for WebSockets (`pre_connect`, `on_open`, `on_message(data)`, `on_close`, `broadcast`, `unicast`, `multicast`, `on_broadcast(data)`, `register_as(identity)`, `notify`).

Here is a Hello World using a Controller class (run in `irb`):

        require 'plezi'

        class Controller
            def index
                "Hello World!"
            end
        end


        route '*' , Controller

        exit # Plezi will autostart once you exit irb.

Except when using WebSockets, returning a String will automatically add the string to the response before sending the response - which makes for cleaner code. It's also possible to use the `response` object to set the response or stream HTTP (return true instead of a stream when you're done).

It's also possible to define a number of controllers for a similar route. The controllers will answer in the order in which the routes are defined (this allows to group code by logic instead of url).

\* please read the demo code for Plezi::StubRESTCtrl and Plezi::StubWSCtrl to learn more. Also, read more about the [Iodine's Websocket and HTTP server](https://github.com/boazsegev/iodine) at the core of Plezi to get more information about the amazing [Request](http://www.rubydoc.info/github/boazsegev/iodine/master/Iodine/Http/Request) and [Response](http://www.rubydoc.info/github/boazsegev/iodine/master/Iodine/Http/Response) objects.

## Native Websocket and Redis support

Plezi Controllers have access to native websocket support through the `pre_connect`, `on_open`, `on_message(data)`, `on_close`, `multicast`, `broadcast`, `unicast` and the Identity API (`register_as` and `notify` methods).

Here is some demo code for a simple Websocket broadcasting server, where messages sent to the server will be broadcasted back to all the **other** active connections (the connection sending the message will not recieve the broadcast).

As a client side, we will use the WebSockets echo demo page - we will simply put in ws://localhost:3000/ as the server, instead of the default websocket server (ws://echo.websocket.org).

Remember to connect to the service from at least two browser windows - to truly experience the `broadcast`ed websocket messages.

```ruby
    require 'plezi'

    # do you need automated redis support?
    # require 'redis'
    # ENV['PL_REDIS_URL'] = "redis://:password@localhost:6379/0"

    class BroadcastCtrl
        def index
            redirect_to 'http://www.websocket.org/echo.html'
        end
        def on_message data
            # try replacing the following two lines are with:
            # self.class.broadcast :_send_message, data
            broadcast :_send_message, data
            response << "sent."
        end
        def _send_message data
            response << data
        end
        def hello
            'Hello!'
        end
        def_special_method "humans.txt" do
            'I made this :)'
        end
    end

    route '/', BroadcastCtrl
```

method names starting with an underscore ('_') are protected from the Http router, even when they are public.

This is why even though both '/hello' and '/humans.txt' are public ( [try it](http://localhost:3000/humans.txt) ), '/_send_message' will return a 404 not found error ( [try it](http://localhost:3000/_send_message) ).

## Adding Websockets to your existing Rails/Sinatra/Rack application

You already have an amazing WebApp, but now you want to add websocket broadcasting and unicasting support - Plezi makes connecting your existing WebApp with your Plezi Websocket backend as easy as it gets.


There are two easy ways to add Plezi websockets to your existing WebApp, depending on your needs and preferences:

1. **The super easy way - a Hybrid app**:

     Plezi plays well with others, so you can add Plezi to your existing framework and let it catch any incoming websocket connections. Your application will still handle anything you didn't ask Plezi to handle (Plezi Websockets and routes will recieve priority, so your app can keep handling the 404 response).


2. **The Placebo API**:

     Plezi has a Placebo API, allowing you to add Plezi features without running a Plezi app.

     By adding the Plezi Placebo to your app, you can easily communicate between your existing app and a remote Plezi process/server. So, although websocket connections are made to a different server, your app can still send and recieve data through the websocket connection (using Redis).

### The super easy way - a Hybrid app

The easiest way to add Plezi websockets to your existing application is to use [Iodine's](https://github.com/boazsegev/iodine) Rack adapter to run your Rack app, while Plezi will use Iodine's native features (such as Websockets and HTTP streaming).

You can eaither use your existing Plezi application or create a new mini plezi application inside your existing app folder using:

    $   plezi mini appname

Next, add the `plezi` gem to your `Gemfile` and add the following line somewhere in your apps code:

```ruby
require './appname/appname.rb'
```

That's it! Now you can use the Plezi API and your existing application's API at the same time and they are both running on the same server.

Plezi's routes will be attempted first, so that your app can keep handling the 404 (not found) error page.

\* just remember to remove any existing servers, such as `thin` of `puma` from your gemfile, otherwise they might take precedence over Plezi's choice of server (Iodine).

### The Plezi Placebo API - talking from afar

To use Plezi and your App on different processes, without mixing them together, simply include the Plezi App in your existing app and call `Plezi.start_placebo` - now you can access all the websocket API that you want from your existing WebApp, but Plezi will not interfere with your WebApp in any way.

For instance, add the following code to your environment setup on a Rails or Sinatra app:

```ruby

require './my_plezi_app/environment.rb'
require './my_plezi_app/routes.rb'

# # Make sure the following is already in your 'my_plezi_app/environment.rb' file:
# ENV['PL_REDIS_URL'] = "redis://:password@my.host:6379/0"
# Plezi::Settings.redis_channel_name = 'unique_channel_name_for_app_b24270e2'

Plezi.start_placebo
```

That's it!

Plezi will automatically set up the Redis connections and pub/sub to connect your existing WebApp with Plezi's Websocket backend - which you can safely scale over processes or machines.

Now you can use Plezi from withing your existing App's code. For example, if your Plezi app has a controller named `ClientPleziCtrl`, you might use:

```ruby
# Demo a Rails Controller:
class ClientsController < ApplicationController
  def update
     #... your original logic here
     @client = Client.find(params[:id])

     # now unicast data to your client on the websocket
     # (assume his websocket uuid was saved in @client.ws_uuid)

     ClientPleziCtrl.unicast @client.ws_uuid, :method_name, @client.attributes

     # or broadcast data to your all your the clients currently connected

     ClientPleziCtrl.broadcast :method_name, @client.attributes

  end
end
```

Easy.

\- "But wait...", you might say to me, "How do we get information back FROM the back end?"

Oh, that's easy too.

With a few more lines of code, we can have the websocket connections _broadcast_ back to us using the `Plezi::Placebo` API.

In your Rails app, add the logic:

```ruby
class MyReciever
    def my_reciever_method arg1, arg2, arg3, arg4...
        # your app's logic
    end
end
Plezi.start_placebo MyReciever
```

Plezi will now take your class and add mimick an IO connection (the Placebo connection) on it's Iodine serever. This Placebo connection will answer the Redis broadcasts just as if your class was a websocket controller...

On the Plezi side, use multicasting or unicasting (but not broadcasting), from ANY controller:

```ruby

class ClientPleziCtrl
    def on_message data
        # app logic here
        multicast :my_reciever_method, arg1, arg2, arg3, arg4...
    end
end
```

That's it! Now you have your listening object... but be aware - to safely scale up this communication you might consider using unicasting instead of broadcasting.

We recommend saving the uuid of the Rails process to a Redis key and picking it up from there.

On your Rails app, add:

```ruby
#...
class MyReciever
    def my_reciever_method arg1, arg2, arg3, arg4...
        # ...
    end
end

pl = Plezi.start_placebo MyReciever

Plezi.redis_connection.set 'MainUUIDs', pl.uuid

```
In your Plezi app, use unicasting when possible:

```ruby
class ClientPleziCtrl
    def on_message data
        # app logic here
        main_uuid = Plezi.redis_connection.get 'MainUUIDs'
        unicast main_uuid, :my_reciever_method, arg1, arg2, arg3, arg4... if main_uuid
    end
end

```

## Native HTTP streaming with Asynchronous events

Plezi comes with native HTTP streaming support (Http will use chuncked encoding unless experimental Http/2 is in use), alowing you to use Plezi Events and Timers to send an Asynchronous response.

Let's make the classic 'Hello World' use HTTP Streaming:

```ruby
        require 'plezi'

        class Controller
            def index
                response.stream_async do
                    sleep 0.5
                    response << "Hello ";
                    response.stream_async{ sleep 0.5; response << "World" }
                end
                true
            end
        end

        route '*' , Controller
```

Notice you can nest calls to the `response.stream_async` method, allowing you to breakdown big blocking tasks into smaller chunks. `response.stream_async` will return immediately, scheduling the task for background processing.

You can also handle other tasks asynchronously using the [Iodine's API](http://www.rubydoc.info/gems/iodine).

More on asynchronous events and timers later.

## Plezi Routes

Plezi supports magic routes, in similar formats found in other systems, such as: `route "/:required/(:optional_with_format){[\\d]*}/(:optional)", Plezi::StubRESTCtrl`.

Plezi assummes all simple routes to be RESTful routes with the parameter `:id` ( `"/user" == "/user/(:id)"` ).

    require 'plezi'

    # this route demos a route for listing/showing posts,
    # with or without revision numbers or page-control....
    # notice the single quotes (otherwise the '\' would need to be escaped).
    route '/post/(:id)/(:revision){[\d]+\.[\d]+}/(:page_number)', Plezi::StubRESTCtrl

now visit:

* [http://localhost:3000/post/12/1.3/1](http://localhost:3000/post/12/1.3/1)
* [http://localhost:3000/post/12/1](http://localhost:3000/post/12/1)

**[please see the `route` documentation for more information on routes](./docs/routes.md)**.

## Plezi Virtual Hosts

Plezi can be used to create virtual hosts for the same service, allowing you to handle different domains and subdomains with one app:

    require 'plezi'

    # define a named host.
    host 'localhost', alias: 'localhost2', public: File.join('my', 'public', 'folder')

    shared_route '/shared' do |req, res|
        res << "shared by all existing hosts.... but the default host doesn't exist yet, so we're only on localhost and localhost2."
    end

    # define a default (catch-all) host.
    host

    shared_route '/humans.txt' do |req, res|
        res << "we are people - we're in every existing hosts."
    end


    route('*') do |req, res|
        res << "this is a 'catch-all' host. you got here by putting in the IP adderess."
    end

    # get's the existing named host
    host 'localhost'

    route('*') do |req, res|
        res << "this is localhost or localhost 2"
    end

Now visit:

* [http://127.0.0.1:3000/]( http://127.0.0.1:3000/ )
* [http://localhost:3000/]( http://localhost:3000/ )
* [http://127.0.0.1:3000/shared]( http://127.0.0.1:3000/shared ) - won't show, becuse this host was created AFTER the route was declered.
* [http://localhost:3000/shared]( http://localhost:3000/shared )
* [http://127.0.0.1:3000/humans.txt]( http://127.0.0.1:3000/humans.txt )
* [http://localhost:3000/humans.txt]( http://localhost:3000/humans.txt )
* notice: `localhost2` will only work if it was defined in your OS's `hosts` file.

## Plezi Logging

The Plezi module (also `PL`) delegates to the Iodine methods, helping with logging as well as the support you already noticed for dynamic routes, dynamic services and more.

Logging:

    require 'plezi'

    # simple logging of strings
    PL.info 'log info'
    Iodine.info 'This is the same, but more direct.'
    PL.warn 'log warning'
    PL.error 'log error'
    PL.fatal "log a fatal error (shuoldn't be needed)."
    PL.log_raw "Write raw strings to the logger."

    # the logger accepts exceptions as well.
    begin
        raise "hell"
    rescue Exception => e
        PL.error e
    end

Please notice it is faster to use the Iodine's API directly when using API that is delegated to Iodine.

## Plezi Events and Timers

The Plezi module (also `PL`) also delegates to the [Iodine's API](http://www.rubydoc.info/gems/greactor/iodine) to help with asynchronous tasking, callbacks, timers and customized shutdown cleanup.

Asynchronous callbacks (works only while services are active and running):

    require 'plezi'

    def my_shutdown_proc time_start
        puts "Services were running for #{Time.now - time_start} seconds."
    end

    # shutdown callbacks
    Iodine.on_shutdown(Kernel, :my_shutdown_proc, Time.now) { puts "this will run after shutdown." }
    Iodine.on_shutdown() { puts "this will run too." }

    # a timer
    Iodine.run_after(2) {puts "this will wait 2 seconds to run... too late. for this example"}

    Iodine.run {puts "notice that the background tasks will only start once the Plezi's engine is running."}
    Iodine.run {puts "exit Plezi to observe the shutdown callbacks."}

## Re-write Routes

Plezi supports special routes used to re-write the request and extract parameters for all future routes.

This allows you to create path prefixes which will be removed once their information is extracted.

This is great for setting global information such as internationalization (I18n) locales.

By using a route with the a 'false' controller, the parameters extracted are automatically retained.

*(Older versions of Plezi allowed this behavior for all routes, but it was deprecated starting version 0.7.4).

    require 'plezi'

    class Controller
        def index
            return "Bonjour le monde!" if params[:locale] == 'fr'
            "Hello World!\n #{params}"
        end
        def show
            return "Vous êtes à la recherche d' : #{params[:id]}" if params[:locale] == 'fr'
            "You're looking for: #{params[:id]}"
        end
        def debug
            # binding.pry
            # do you use pry for debuging?
            # no? oh well, let's ignore this.
            false
        end
        def delete
            return "Mon Dieu! Mon français est mauvais!" if params[:locale] == 'fr'
            "did you try #{request.base_url + request.original_path}?_method=delete or does your server support a native DELETE method?"
        end
    end

    # this is our re-write route.
    # it will extract the locale and re-write the request.
    route '/:locale{fr|en}/*', false

    # this route takes a regular expression that is a simple math calculation
    # (calculator)
    #
    # it is an example for a Proc controller, which can replace the Class controller.
    route /^\/[\d\+\-\*\/\(\)\.]+$/ do |request, response|
        message = (request.params[:locale] == 'fr') ? "La solution est" : "My Answer is"
        response << "#{message}: #{eval( request.path[1..-1] )}"
    end

    route "/users" , Controller

    route "/" , Controller

try:

* [http://localhost:3000/](http://localhost:3000/)
* [http://localhost:3000/fr](http://localhost:3000/fr)
* [http://localhost:3000/users/hello](http://localhost:3000/users/hello)
* [http://localhost:3000/users/(5+5*20-15)/9.0](http://localhost:3000/users/(5+5*20-15)/9.0) - should return a 404 not found message.
* [http://localhost:3000/(5+5*20-15)/9.0](http://localhost:3000/(5+5*20-15)/9)
* [http://localhost:3000/fr/(5+5*20-15)/9.0](http://localhost:3000/fr/(5+5*20-15)/9)
* [http://localhost:3000/users/hello?_method=delete](http://localhost:3000/users/hello?_method=delete)

As you can see in the example above, Plezi supports Proc routes as well as Class controller routes.

Please notice that there are some differences between the two. Proc routes less friedly, but plenty powerful and are great for custom 404 error handling.

## OAuth2 and other Helpers

Plezi has a few helpers that help with common tasks.

For instance, Plezi has a built in controller that allows you to add social authentication using Google, Facebook
and and other OAuth2 authentication service. For example:

    require 'plezi'

    class Controller
        def index
            flash[:login] ? "You are logged in as #{flash[:login]}" : "You aren't logged in. Please visit one of the following:\n\n* #{request.base_url}#{Plezi::OAuth2Ctrl.url_for :google}\n\n* #{request.base_url}#{Plezi::OAuth2Ctrl.url_for :facebook}"
        end
    end

    # set up the common social authentication variables for automatic Plezi::OAuth2Ctrl service recognition.
    ENV["FB_APP_ID"] ||= "facebook_app_id / facebook_client_id"
    ENV["FB_APP_SECRET"] ||= "facebook_app_secret / facebook_client_secret"
    ENV['GOOGLE_APP_ID'] = "google_app_id / google_client_id"
    ENV['GOOGLE_APP_SECRET'] = "google_app_secret / google_client_secret"

    require 'plezi/oauth'

    # manually setup any OAuth2 service (we'll re-setup facebook as an example):
    Plezi::OAuth2Ctrl.register_service(:facebook, app_id: ENV['FB_APP_ID'],
                    app_secret: ENV['FB_APP_SECRET'],
                    auth_url: "https://www.facebook.com/dialog/oauth",
                    token_url: "https://graph.facebook.com/v2.3/oauth/access_token",
                    profile_url: "https://graph.facebook.com/v2.3/me",
                    scope: "public_profile,email") if ENV['FB_APP_ID'] && ENV['FB_APP_SECRET']


    create_auth_shared_route do |service_name, token, remote_user_id, remote_user_email, remote_response|
        # we will create a temporary cookie storing a login message. replace this code with your app's logic
        flash[:login] = "#{remote_response['name']} (#{remote_user_email}) from #{service_name}"
    end

    route "/" , Controller

    exit

Plezi has a some more goodies under the hood.

Whether such goodies are part of the Plezi-App Template (such as rake tasks for ActiveRecord without Rails) or part of the Plezi Framework core (such as descried in the Plezi::ControllerMagic documentation: #flash, #url_for, #render, #send_data, etc'), these goodies are fun to work with and make completion of common tasks a breeze.


## Plezi Settings

Plezi leverages [Iodine's server](https://github.com/boazsegev/iodine) new architecture. Iodine is a pure Ruby HTTP and Websocket Server built using [Iodine's](https://github.com/boazsegev/iodine) core library - a multi-threaded pure ruby alternative to EventMachine with process forking support (enjoy forking, if your code is scaling ready).

Plezi and Iodine are meant to be very effective, allowing for much flexability where needed.

Settings for the Iodine's core allow you to change different things, such as the level of concurrency you want (`Iodine.threads = ` or `Iodine.processes = `), logging destination (such as logging to a file) and more.

Settings for Iodine's Http and Websockets server, allow you to change upload limits (which can be super important for security) using `Iodine::Http.max_http_buffer =`, limit websocket message sizes using `Iodine::Http::Websockets.message_size_limit =`, change the Websocket's auto-ping interval using `Iodine::Http::Websockets.default_timeout =` or `Plezi::Settings.ws_message_size_limit` and more... Poke around ;-)

Plezi and Iodine are written for Ruby versions 2.1.0 or greater (or API compatible variants). Version 2.2.3 is the currently recommended version.

## Who's afraid of multi-threading?

Let's start with the obvious, **if** your code is short and efficient (no blocking tasks), it is best to run Plezi (Iodine) in a single threaded mode - you get better performance AND safer code, **as long as there are no blocking tasks**:

      Plezi.threads = 1

But... most applications will naturally have blocking tasks, such as database queries etc'. This is why...:

Plezi builds on Iodine's concept of "connection locking", meaning that your controllers shouldn't be acessed by more than one thread at the same time.

This allows you to run Plezi as a multi-threaded (and even multi-process) application as long as your controllers don't change or set any global data... Readeing global data after it was set during initialization is totally fine, just not changing or setting it...

But wait, global data is super important, right?

Well, sometimes it is. And although it's a better practice to avoide storing any global data in global variables (databases are usually thread safe storage places), sometimes storing stuff in the global space is exactly what we need.

The solution is simple - if you can't use persistent databases with thread-safe libraries (i.e. Sequel / ActiveRecord / Redis, etc'), use Plezi's global cache storage (see Plezi::Cache).

Plezi's global cache storage is a local memory based storage protected by a mutex whenever reading or writing from the cache.

So... these are protected:

    # set data
    Plezi.cache_data :my_global_variable, 32
    # get data
    Plezi.get_cached :my_global_variable # => 32

However, although Ruby seems innocent, it's super powerful when it comes to using pointers and references behind the scenes. This could allow you to change a protected object in an unprotected way... consider this:

    a = []
    b = a
    b << '1'
    # we changed `a` without noticing
    a # => [1]

For this reason, it's important that Strings, Arrays and Hashes will be protected if they are to be manipulated in any way.

The following is safe:

    # set data
    Plezi.cache_data :global_hash, Hash.new
    # manipulate data
    Plezi.get_cached :global_hash do |global_hash|
        global_hash[:change] = "safe"
    end

However, the following is unsafe:

    # set data
    Plezi.cache_data :global_hash, Hash.new
    # manipulate data
    global_hash = Plezi.get_cached :global_hash do |global_hash|
    global_hash[:change] = "NOT safe"


\* be aware, if using Plezi in as a multi-process application, that each process has it's own cache and that processes can't share the cache. The different threads in each of the processes will be able to access their process's cache, but each process runs in a different memory space, so they can't share.

## Contributing

Feel free to fork or contribute. right now I am one person, but together we can make something exciting that will help us enjoy Ruby in this brave new world and (hopefully) set an example that will induce progress in the popular mainstream frameworks such as Rails and Sinatra.

1. Fork it ( https://github.com/boazsegev/plezi/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# [<img src='https://raw.githubusercontent.com/boazsegev/plezi/master/logo/sign.png' alt='Plezi' style='width:20em;' />](http://www.plezi.io)
