class ActiveRecord::Associations::CollectionAssociation

  def load_target_with_jit
    if !loaded? && owner.persisted? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    was_loaded = loaded?    
    load_target_without_jit.tap do |records|
      if !was_loaded        
        JitPreloader::Preloader.attach(records) if records.any? && (owner.jit_preloader || JitPreloader.globally_enabled?)
        ActiveSupport::Notifications.publish("n_plus_one_query", source: owner, association: reflection.name) if owner.jit_n_plus_one_tracking && loaded?
      end
    end
  end
  alias_method_chain :load_target, :jit
end