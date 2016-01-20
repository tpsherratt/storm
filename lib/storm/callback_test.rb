# module Storm
#   class CallbackTest
#     #extend Storm::Callbacks::ClassMethods
#     include Storm::Callbacks

#     define_callbacks :save

#     before_save :before
#     before_save :hi
#     after_save :after

#     def save
#       run_callbacks :save, "word up home boy" do
#         puts "Saving"
#       end
#     end

#     def before(obj)
#       puts "before saving - #{obj}"
#     end

#     def hi(obj)
#       puts "more before"
#     end

#     def after(obj)
#       puts "after saving - #{obj}"
#     end

#   end
# end