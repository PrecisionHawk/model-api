# model-api gem - api_model options reference
Usage information for `api_model` method, defining model-class-level metadata for processing API
endpoint calls.

## Annotated Example
``` ruby
class MyModelClass < ActiveRecord::Base
  # ...

  api_model(

      # Only return objects the user owns unless viewing as an administrator
      base_query:
          (lambda do |opts|
            return self.all if opts[:admin]
            query.where('my_model_objects.user_id' => opts[:user_id])
          end),

      # Configure object to be uniquely identified by ID, name, or combination of user and role
      id_attributes: [:id, :name, [:user_id, :role]],

      # Control access by user, API operation category, and object (where applicable)
      validate_create: -> (obj, opts) { opts[:user].can_create?(obj) },
      validate_show: -> (obj, opts) { opts[:user].can_view?(obj) },
      validate_index: -> (opts) { opts[:user].can_view_list? },
      validate_update: -> (obj, opts) { opts[:user].can_update?(obj) },
      validate_destroy: -> (obj, opts) { opts[:user].can_destroy?(obj) },

      # Add an extra validation step before running the object's own validate() method.  (Note the
      #   any errors that already exist on the object will be preserved.)
      before_validate:
          (lambda do |obj, opts|
            unless obj.serial_number =~ %r{^\d{5}$} || obj.serial_number =~ %r{^\d{9}$} 
              obj.errors.add(:serial_number, 'must be a 5-digit or 9-digit value')
            end
          end), 

      # Set the created_by field to current user before creating record
      before_create:
          (lambda do |obj, opts|
            obj.created_by = opts[:user]
          end),

      # Set the last_updated_by field to current user before saving record
      before_save:
          (lambda do |obj, opts|
            obj.last_updated_by = opts[:user]
          end),
   
      # When rendering as a collection, specify associations to be automatically pre-loaded
      collection_includes: [:address, friends: [:address, :followers]]
  )

  # ...
}
```

## Database Mapping / Scoping

#### `base_query`
*Provides a base query that limits what objects appear in the API based on the context (current
user, etc.).*  Default: `nil`.  Specified as a callback with the following optional argument:
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `id_attributes`
*Indicate attributes that can be used to uniquely identify objects of this type.*  Default: `nil`.
Specified as an array whose elements are one of the following:
 * Individual attribute that uniquely identifies the record.
 * Array of attributes that together can uniquely identify the record.
 
## Validate / Authenticate API Operations

#### `validate_create`
*Verify an API create operation is acceptable in the current context.*  Default: `nil`.  Specified
as a callback with the following optional arguments:
  * `obj` - Prepared ActiveRecord object that's about to be created
  * `opts` - Options collection (See
      [Common Callback Options](general_info.md#common-callback-options) for details)
      
From within this callback, options for controlling the outcome of the operation include:
  * Raising a `ModelApi::UnauthorizedException` to indicate lack of access.
  * Raising a `ModelApi::NotFoundException` to indicate the resource wasn't found.
  * Adding an error entry to `obj.errors` with details on why the create failed.

#### `validate_show`
*Verify rendering of an individual object via the API is acceptable in the current context.*
Default: `nil`.  Specified as a callback with the following optional arguments:
  * `obj` - ActiveRecord object that's about to be viewed
  * `opts` - Options collection (See
      [Common Callback Options](general_info.md#common-callback-options) for details)
      
From within this callback, options for controlling the outcome of the operation include:
  * Raising a `ModelApi::UnauthorizedException` to indicate lack of access.
  * Raising a `ModelApi::NotFoundException` to indicate the resource wasn't found.

#### `validate_index`
*Verify rendering of a collection of objects via the API is acceptable in the current context.*
Default: `nil`.  Specified as a callback with the following optional arguments:
  * `opts` - Options collection (See
      [Common Callback Options](general_info.md#common-callback-options) for details)
      
From within this callback, options for controlling the outcome of the operation include:
  * Raising a `ModelApi::UnauthorizedException` to indicate lack of access.
  * Raising a `ModelApi::NotFoundException` to indicate the resource wasn't found.

#### `validate_update`
*Verify an API create operation is acceptable in the current context.*  Default: `nil`.  Specified
as a callback with the following optional arguments:
  * `obj` - Modified ActiveRecord object whose changes are about to be committed
  * `opts` - Options collection (See
      [Common Callback Options](general_info.md#common-callback-options) for details)
      
From within this callback, options for controlling the outcome of the operation include:
  * Raising a `ModelApi::UnauthorizedException` to indicate lack of access.
  * Raising a `ModelApi::NotFoundException` to indicate the resource wasn't found.
  * Adding an error entry to `obj.errors` with details on why the update failed.

#### `validate_destroy`
*Verify an API destroy operation is acceptable in the current context.*  Default: `nil`.  Specified
as a callback with the following optional arguments:
  * `obj` - Modified ActiveRecord object whose changes are about to be committed
  * `opts` - Options collection (See
      [Common Callback Options](general_info.md#common-callback-options) for details)

From within this callback, options for controlling the outcome of the operation include:
  * Raising a `ModelApi::UnauthorizedException` to indicate lack of access.
  * Raising a `ModelApi::NotFoundException` to indicate the resource wasn't found.
  * Adding an error entry to `obj.errors` with details on why the destroy failed.

## Object Life Cycle Callbacks

#### `before_validate`
*Perform custom steps before an object is about to be validated via the API.*  Default: `nil`.
Specified as a callback with the following optional arguments:
  * `obj` - Modified ActiveRecord object whose changes are pending validation
  * `opts` - Options collection (See
       [Common Callback Options](general_info.md#common-callback-options) for details)

#### `before_create`
*Perform custom steps before an object is about to be created via the API.*  Default: `nil`.
Specified as a callback with the following optional arguments:
  * `obj` - Prepared ActiveRecord object whose changes are validated and about to be committed
  * `opts` - Options collection (See
       [Common Callback Options](general_info.md#common-callback-options) for details)

#### `before_save`
*Perform custom steps before an object is about to be created or updated via the API.*
Default: `nil`.  Specified as a callback with the following optional arguments:
  * `obj` - Modified ActiveRecord object whose changes are validated and about to be committed
  * `opts` - Options collection (See
       [Common Callback Options](general_info.md#common-callback-options) for details)
