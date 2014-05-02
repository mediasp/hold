require 'rubygems'

require 'test/unit'
require 'test/spec'
require 'mocha/setup'

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

# We don't want Test::Unit::TestCase to run test methods from a superclass.
# This is the way the more recent test-unit gems work, but requires a monkey-patch
# to the stdlib's test/unit. (Unfortunately the more recent test-unit gems have
# some compatibility issues with test-spec)
module Test::Unit
  class TestCase
    def self.suite
      # DIFF ON THE FOLLOWING LINE ONLY - true changed to false to exclude superclass methods
      method_names = public_instance_methods(false)
      tests = method_names.delete_if {|method_name| method_name !~ /^test./}
      suite = TestSuite.new(name)
      tests.sort.each do
        |test|
        catch(:invalid_test) do
          suite << new(test)
        end
      end
      if (suite.empty?)
        catch(:invalid_test) do
          suite << new("default_test")
        end
      end
      return suite
    end
  end
end
