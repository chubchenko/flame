# frozen_string_literal: true

module Flame
	class Dispatcher
		## Module for working with routes
		module Routes
			private

			## Find route and try execute it
			def try_route
				http_method = request.http_method
				http_method = :GET if http_method == :HEAD
				return unless available_endpoint

				route = available_endpoint[http_method]
				return unless route || available_endpoint.allow

				halt(405, nil, 'Allow' => available_endpoint.allow) unless route
				status 200
				execute_route route
				true
			end

			## Execute route
			## @param route [Flame::Route] route that must be executed
			def execute_route(route, action = route.action)
				params.merge!(
					router.path_of(route).extract_arguments(request.path)
				)
				# route.execute(self)
				@current_controller = route.controller.new(self)
				@current_controller.send(:execute, action)
			rescue StandardError, SyntaxError => e
				# p 'rescue from dispatcher'
				dump_error(e)
				status 500
				@current_controller&.send(:server_error, e)
				# p 're raise error from dispatcher'
				# raise e
			end

			## Generate a default body of nearest route
			def default_body_of_nearest_route
				## Return nil if must be no body for current HTTP status
				return if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status)

				## Find the nearest route by the parts of requested path
				route = router.find_nearest_route(request.path)
				## Return standard `default_body` if the route not found
				return default_body unless route

				return not_found_body(route) if response.not_found?

				controller =
					(@current_controller if defined?(@current_controller)) || route.controller.new(self)
				controller.send :default_body
			end

			def not_found_body(route)
				## Execute `not_found` method as action for the founded route
				execute_route(route, :not_found)
				body
			end
		end
	end
end
