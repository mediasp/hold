require 'rubygems'
require 'test/spec'
require 'mocha'

# replace 'instance_eval' with 'class_eval' in this method from test/spec, to allow shared contexts to
# define helper methods as well as declare specs.
# todo: pull request for this on github
module Test::Spec::TestCase::ClassMethods
  def behaves_like(shared_context)
    if Test::Spec::SHARED_CONTEXTS.include?(shared_context)
      Test::Spec::SHARED_CONTEXTS[shared_context].each { |block|
        class_eval(&block)
      }
    elsif Test::Spec::SHARED_CONTEXTS.include?(self.name + "\t" + shared_context)
      Test::Spec::SHARED_CONTEXTS[self.name + "\t" + shared_context].each { |block|
        class_eval(&block)
      }
    else
      raise NameError, "Shared context #{shared_context} not found."
    end
  end
end
