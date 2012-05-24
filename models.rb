class Catagory
    include Mongoid::Document
    include Mongoid::Timestamps

    field :href
    field :title
    field :sellers

end

class Seller
    include Mongoid::Document
    include Mongoid::Timestamps

    #basic info
    field :uri
    field :type
    field :number
    field :name
    field :catagory_name
    field :has_store
    #feedback
    field :positive_feedback
    field :feedback_score
    field :ratings
    field :feedback_detail
    #contact_deails
    field :info

end

class Failure
  include Mongoid::Document
  include Mongoid::Timestamps

  field :response
  field :type
  field :uri
end
