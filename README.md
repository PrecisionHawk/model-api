# model_api
Rails REST API's made easy.

## Why use model-api?
Developing REST API's in a conventional manner involves many challenges.  Between the parameters,
 route details, payloads, responses, and API documentation, it's difficult to find an implementation
 strategy that minimizes repetition and organizes the details in a simple, easy-to-maintain manner.
 This is where model-api comes in.
   
 With model-api, you can:
  * Consolidate your payload and response metadata for a given resource in the ActiveRecord model.
  * Set up easily-configurable filtering, pagination, sorting, and HATEOAS link generation.
  * Render, link, create, search upon, and sort upon your resources' associated objects with ease.
  * Easily leverage the ActiveRecord validation rules present in your application's models to
    validate calls to your API.
  * Automatically generate OpenAPI documentation with each deployment that's guaranteed to be in
    sync with what your API actually supports.
  * Reduce the lines of code required to implement your Rails-based Rest API dramatically.

## Guides
This README file is intended to provide a brief introduction.  For more detailed information,
the following guides are available:
* [Guide to `api_attributes` metadata](doc/api_attributes.md)
* [Guide to `api_model` metadata](doc/api_model.md)
* [Managing data access in `model-api`](doc/managing_data_access.md)

General information on the API (including enumerated constants, etc.) can be found here:
* [General gem usage information](doc/general_info.md)

## Installation
 
Put this in your Gemfile:

``` ruby
gem 'model-api'
```

## Configuration

The `model-api` gem doesn't require configuration.  However, if you plan to generate OpenAPI
 documentation, add an `open_api.rb` file to `config/initializers` and configure as follows:

``` ruby
OpenApi.configure do |config|

  # Default base path(s), used to scan Rails routes for API endpoints.
  config.base_paths = ['/widget-api/v1']

  # General information about your API.
  config.info = {
      title: 'Acme Widget API',
      description: "Documentation of the Acme's Widget API service",
      version: '1.0.0',
      terms_of_service: 'https://www.acme.com/widget-api/terms_of_service',

      contact: {
          name: 'Acme Corporation API Team',
          url: 'http://www.acme.com/widget-api',
          email: 'widget-api-support@acme.com'
      },

      license: {
          name: 'Apache 2.0',
          url: 'http://www.apache.org/licenses/LICENSE-2.0.html'
      }
  }

  # Default output file path for your generated Open API JSON document.
  config.output_file_path = Rails.root.join('apidoc', 'api-docs.json')
end
```

## Exposing a Resource

To expose a resource, start by defining the underlying model for that resource: 
``` ruby
class Book < ActiveRecord::Base
  include ModelApi::Model
  
  # Valication rules are utilized by model-api to validate requests
  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :description, length: { maximum: 250 }
  validates :isbn, presence: true, uniqueness: true, length: { maximum: 13 }
  
  # Define the attributes exposed via the REST API.
  api_attributes \
      id: { filter: true, sort: true },
      name: { filter: true, sort: true },
      description: {},
      isbn: { filter: true, sort: true,
          parse: ->(v) { v.to_s.gsub(%r{[^\d]+}, '') },
          render: ->(v) { "#{v[0..2]}-#{v[3]}-#{v[4..5]}-#{v[6..11]}-#{v[12..-1]}" }
      },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
```
An explanation of the options used in the `api_attributes` example above:
* `filter` - Allow filtering by query string parameters (e.g. `?id=123`).
* `sort` - Allow use of this column in the sort_by parameter.
* `read_only` - Disallow column updates (via `POST`, `PUT`, or `PATCH`).
* `parse` - Method name (e.g. `:to_i`) or proc / lambda for pre-processing incoming payload values.
  *(The example lambda removes any non-digit values (such as dashes) from supplied ISBN values.)*
* `render` - Method name or proc / lambda that formats values returned in response payloads.
  *(The example lambda formats the 13-digit ISBN number using the typical dash convention.)*
 
Next, define the base controller class that all of your API controllers will extend 
(for this example, in `app/controllers/api/v1/base_controller.rb`):
```ruby
  module Api
    module V1
      class BaseController < ActionController::Base
        include ModelApi::BaseController
        include ModelApi::OpenApiExtensions
        include OpenApi::Controller
        
        # OpenAPI documentation metadata shared by all endpoints, including common query string
        #  parameters, HTTP headers, and HTTP response codes.
        open_api_controller \
            query_string: {
                access_token: {
                    type: :string,
                    description: 'OAuth 2 access token query parameter',
                    required: false
                }
            },
            headers: {
                'Authorization' => {
                    type: :string,
                    description: 'Authorization header (format: "bearer &lt;access token&gt;")',
                    required: false
                }
            },
            responses: {
                200 => { description: 'Successful' },
                400 => { description: 'Not found' },
                401 => { description: 'Invalid request' },
                403 => { description: 'Not authorized (typically missing / invalid access token)' }
            }
        
        # OpenAPI documentation for common API endpoint path parameters
        open_api_path_param :book_id, description: 'Book identifier'
        
        # HATEOAS links common to all responses (e.g. a common terms-of-service link)
        def common_response_links(_opts = {})
          { 'terms-of-service' => URI(url_for(controller: '/home', action: :terms_of_service)) }
        end
      end
    end
  end
```

Add the resource routes to your `routes.rb` file:
```ruby
  namespace :api do
    namespace :v1 do
      resource :books, except: [:new, :edit], param: :book_id
    end
  end
```

Finally, add a controller for your new resource (for this example, in
`app/controllers/api/v1/base_controller.rb`): 
```ruby
  module Api
    module V1
      class BooksController < BaseController
        class << self
        
          # Default model class to use for API endpoints in this controller
          def model_class
            Book
          end
          
          # Default options for model-api helper methods used to process requests to endpoints 
          def base_api_options
            super.merge(id_param: :book_id)
          end
        end
        
        # OpenAPI metadata describing the collective set of endpoints defined in this controller 
        open_api_controller \
            tag: {
            name: 'Books',
            description: 'Comprehensive list of available books'
        }

        # GET /api/v1/books endpoint OpenAPI doc metadata and implementation
        add_open_api_action :index, :index, base_api_options.merge(
            description: 'Retrieve list of available books')
        def index
          render_collection collection_query, base_api_options
        end
        
        # GET /api/v1/books/:book_id endpoint OpenAPI doc metadata and implementation
        add_open_api_action :show, :show, base_api_options.merge(
            description: 'Retrieve details for a specific book')
        def show
          render_object object_query.first, base_api_options
        end
        
        # POST /api/v1/books endpoint OpenAPI doc metadata and implementation
        add_open_api_action :create, :create, base_api_options.merge(
            description: 'Create a new book')
        def create
          do_create base_api_options
        end
        
        # PATCH/PUT api/v1/books/:book_id endpoint OpenAPI doc metadata and implementation
        add_open_api_action :update, :update, base_api_options.merge(
            description: 'Update an existing book')
        def update
          do_update object_query, base_api_options
        end
        
        # DELETE /api/v1/books/:book_id endpoint OpenAPI doc metadata and implementation
        add_open_api_action :destroy, :destroy, base_api_options.merge(
            description: 'Delete an existing book')
        def destroy
          do_destroy object_query, base_api_options
        end

        def object_query(opts = {})
          super(opts.merge(not_found_error: true))
        end
      end
    end
  end
```

## Generating Documentation

To generate OpenAPI documentation:
```
    rake open_api:docs
```

Optionally, you may specify a base route path and output file:
```
    rake open_api:docs[/api/v1,/home/myhome/api-v1.json]
```
