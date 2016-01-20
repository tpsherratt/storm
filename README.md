# Storm

TL;DR - saving models innit. Skip down to usage.

### Things to be aware of:
It is not currently possible to call .to_json on an object that inherits from Storm::BaseModel (i.e. League, Team, etc). Doing so will cause a stack level too deep error, so be aware of that during development until it is fixed.

### Storm is the STeak ORM.

This is what should be used throughout Steak for object persistance (instead of ActiveRecord).

It follows the Data Mapper pattern (rather than the ActiveRecord pattern), putting a layer between our domain models, and their persistence. The major outworkings of this are:
* Models can nolonger persist themselves, thus each of them has a `Manager` to do it for them. eg `UserManager.save(user)`
* As models aren't modeling a database row, they must explicitly define their attributes. eg. `attributes :id, :my_attr, :my_other_attr`
* You can't access related objects by doing `division.teams`, instead do `TeamManager.find_by_division_id(division.id)`

## Why?
The reason for using a data mapper pattern at all is to remove all circular dependencies between our models. This allows us to split our models into different engines that do not depend on eachother, giving us much greater flexibility (at the cost of a little more typing) as our product grows very large.

This forced separate means that once we get to large scale we will not be dealing with a web of dependencies, and ultimatley will easily be able to split out apps that provide a subset of our main app's functionality if (when) we're forced to do so as we scale up.


## How?
There's a lot of good and very clever stuff in ActiveRecord that it makes sense to make use of (eg. SQL generation), so we've built storm as a layer on top of that.

Much like `ActiveRecord::Base` does for Rails models, we've written two base classes that provide core functionality for our domain models and our managers. These are `Storm::BaseModel` and `Storm::BaseManager` respectively.

The bulk of the complexity is in `Storm::BaseManager`. In this implimentation it pretty much just turns domain objects into record (ie. rails) objects and, then calls appropriate persistence related methods on them, or builds domain objects from records objects and sets some internal state.

## Usage
When creating a new model, you now need to create three classes

1. Domain Model - The model used throughout steak.
2. Record Model (plus migrations) - Used by storm to _actually_ persist your model.
3. Manager - The class you use to load/persist your domain model.


### Domain Models
Pretty simple stuff:

    class User < Storm::BaseModel
      # define our attrs
      attributes :id, :email, :name
      
      # add methods as normal
      def surname
        name.split(" ").last
      end
    end

    user_one = User.new
    user_one.name = "Timothy Sherratt"
    
    # set attrs with a hash
    user_two = User.new(name: "Timothy Sherratt")


### Record Models
We're essentially using ActiveRecord as our SQL generation engine, because of this record models _are_ normal ActiveRecord::Base models, __however__ they inherit from `Storm::BaseRecord` as this allows us to add extra functionality to that which `ActiveRecord::Base` provides. 

As we're only concerned only with getting stuff into the database, the only stuff that should be in these models is stuff todo with that. As AR models get all the config from DB structure, all we're left with are validations to make sure our data is in the correct format.

When writing your migrations, make sure that your column names exactly match your domain model attribute names or errors will ensue!

    class CreateUsers < ActiveRecord::Migration
      def change
        create_table :users do |t|
          t.string :name
          t.string :email
        end
      end
    end

    class UserRecord < Storm::BaseRecord
      validates presence: true, :name
    end


    
### Managers
Each model needs a manager. This class essentially handles the translation between the domain models, and our record models used for saving. Manager method names have been borrowed heavily from ActiveRecord, so should feel familiar.

Basic persistence/loading functionality is provided entirely by BaseManager, so there is very little you need to do...

    class UserManager < Storm::BaseManager; end

    um = UserManager.new
    user = User.new(name: "Timothy Sherratt")

#### Basic Usage
Saving:

    user.id 
    # => nil
    um.save(user)
    # => true
    user.id 
    # => 1
    
    # :save, and :save! as you would expect
    user.name = nil
    um.save(user)
    # => false
    
    um.save!(user)
    # => Storm::RecordInvalidError "validation failed..."


Updating
    
    user.email = "tim@mitoo.co"
    um.save(user)
    # => true
    
Loading

    # by id
    user = um.find(1)
    # => #<User id: 1, ...
    
    # by an attr
    user = um.find_by_email("tim@mitoo.co")
    # => #<User id: 1, ...    
    
    # first, second, third, fourth
    user = um.first
    # => #<User id: 1, ...    
    
    # where
    um.where(email: "tim@mitoo.co")
    # => [#<User id: 1, ...    ]   # returns array
    
Deleting
Soft delete is built into Storm, and is what you should use when you do not have a specific reason to do otherwise

    # soft delete
    um.destroy(user)
    # => true
    
    # real delete
    um.real_delete!(user)
    # => true
    
#### Extras

#####Generate Your Files!
I only went a wrote a bloody generator.
    
    $ cd components/users
    $ rails g storm_model my_model
    # =>  create app/models/users/my_model.rb
    # =>  create app/models/users/my_model_manager.rb
    # =>  create app/models/users/my_model_record.rb

#####Custom Manager Functionality

You can define your own methods on your managers.
See the code for a few (protected) methods exposed to allow for more complex stuff (but use with caution).

    class TeamManager < Storm::BaseManager
      # contrived example, obvs
      def teams_in_my_fave_league
        self.where(league_: 2)
      end
    end
    
`find_by_sql` is one of the `protected` methods that is exposed for use within managers. This is good because it allows you to setup queries with joins etc. But __you must remember__:

* Caching, especially if you're writing complex/long-running queries.
* To check `trashed_at IS NULL`

```
    module LeagueModels
      class LeagueManager < Storm::BaseManager
        def find_by_user_enquiries(user_id)
          q = "SELECT l.* \
            FROM league_models_leagues l, league_models_league_enquiries le \
            WHERE l.id=le.league_id AND le.user_id=? \
            AND le.trashed_at IS NULL \
            AND l.trashed_at IS NULL"
          self.find_by_sql [q, user_id]
        end
      end
    end
```

#####Non-Standard Naming

    class CupRecords < Storm::BaseRecord; end
    
    class LeagueManager < Storm::BaseManager
      set_domain_class Comps
      set_record_class CupRecords
    end
    
    class Comps < Storm::BaseModel
      set_manager_class LeagueManager
     end

#####Saving an instance of a mystery model
You can get from the model to the manager, if you need to. It is not recommended to use this functionality outside of when you're dealing with polymorphic relationships etc. as it could cover up bugs, and make code less obvious/readable.

    mngr = my_isnt.manager
    mngr.save! my_inst

#####Callbacks

In Storm lifecycle callbacks are on the Manager rather than the Model, as it is the Manager rather than the model that knows about these events.

The major difference between this and ActiveRecord callbacks is that as we're dealing with a manager, the methods we define to be called must accept one argument, which will be the instance of the domain model being saved.

We currently have :create, :update, :save and :desctroy callbacks, and before_xxx/after_xxx expect :method_name.

    class UserManager < Storm::BaseManager
      before_save :my_before_method
      after_save :my_after_method
      
      def my_before_method(obj)
        put "about to save user id #{obj.id}"
      end
      
      def my_after_method(obj)
        put "finished saving user id #{obj.id}"
      end    
    end
    
    UserManager.new.save(my_user)
    # => "about to save user id 1"
    # => "finished saving user id 1"


##### Single Table Inheritance
Allow different models that inherit from eachother to be persisted to a single db table.

In simple terms, this works by saving the class of the instance into its db row in a column called `:sti_type` (lolz), and then just letting the Manager know that it has to take this into account. So...

* Create the column
```ruby
    class AddStiTypeToResults < ActiveRecord::Migration
      def change
        add_column :results, :sti_type, :string
      end
    end
```

* Let the manager know
```ruby
    class ResultsManager < BaseManager
      single_table_inheritance
    end
```

* That's it...

```ruby
    manager = ResultManager.new
    result = Result.new(id: 1)
    hw_result = HomeWalkoverResult.new(id: 2)
    
    manager.save! result
    manager.save! hw_result
    
    manager.find(1).class.name
    # => 'Result'
    
    manager.find(2).class.name
    # => 'HomeWalkoverResult'
```

P.S. If you want to convert an instance from one of your STI types to another, you can use the `:becomes` method (which works very similarly to its AR namesake).

```ruby
    result = manager.find(1)
    result = result.becomes(HomeWalkoverResult)
    
    result.id
    # => 1
    result.class.name
    # => 'HomeWalkoverResult'
```

    
##### Auto-instantiation of managers
Save a few keystrokes by getting storm to instantiate our desired manager and put it in @mngr before each request.

    module LeagueApi
      class V1::LeaguesController < ApplicationController
    
        mngr LeagueModels::LeagueManager
    
        def show
          @league = @mngr.find(params[:id])
          render 'leagues/league'
        end
      end
    end

    
    

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'storm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install storm

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( https://github.com/[my-github-username]/storm/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
