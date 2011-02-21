module Persistence
  # This is sort of a lightweight service locator / DI container for a set of inter-related repositories.
  # It provides some glue to help them find eachother, and to help you find a repository for any given model class.
  #
  # TODO: split off the more generic DI functionality into a DI container superclass
  class RepositorySet
    def initialize(db)
      @db = db
      @repos_by_model_class = {}
      @repos_by_name = {}
      @repos = []
      yield self
      @repos.each {|repo| repo.get_repo_dependencies_from(self)}
      inject_into(self) # clever huh
    end

    attr_reader :repos

    # Some more fine-grained dependency-finding interfaces to get a repository for a
    # particular model_class or a superclass or polymorphic union thereof.
    # TODO: ability to specify if you need a writeable repo or just a readable one.

    def repo_for_model_class(model_class)
      @repos_by_model_class[model_class]
    end

    def repo_for_model_class_or_superclass(model_class)
      @repos_by_model_class[model_class] || @repos.find {|r| r.can_get_class?(model_class)}
    end

    def repo(name, klass, *args)
      repo = klass.new(@db, *args)

      if repo.respond_to?(:model_class)
        @repos_by_model_class[repo.model_class] = repo
      end
      @repos_by_name[name] = repo
      @repos << repo
    end

    # A transaction on all the repositories contained within (since we constructed them all off the same database)
    def transaction(*p, &b)
      @db.transaction(*p, &b)
    end

    # inject_into(foo) # injects all repos
    # inject_into(foo, :foo_repo, :bar_repo) # only these ones
    # inject_into(foo, :foo_repo => :injected_aliased_as_this)
    def inject_into(instance, *names)
      metaclass = class << instance; self; end

      names = names.first if names.first.is_a?(Hash)
      names = @repos_by_name.keys if names.empty?
      names.each do |name, alias_as|
        alias_as ||= name
        instance.instance_variable_set("@#{alias_as}", @repos_by_name[name])
        metaclass.send(:attr_reader, alias_as)
      end
    end
  end
end
