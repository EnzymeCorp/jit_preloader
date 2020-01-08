module JitPreloader
  module PreloaderAssociation

    # A monkey patch to ActiveRecord. The old method looked like the snippet
    # below. Our changes here are that we remove records that are already
    # part of the target, then attach all of the records to a new jit preloader.
    #
    # def run(preloader)
    #   records = load_records do |record|
    #     owner = owners_by_key[convert_key(record[association_key_name])]
    #     association = owner.association(reflection.name)
    #     association.set_inverse_instance(record)
    #   end

    #   owners.each do |owner|
    #     associate_records_to_owner(owner, records[convert_key(owner[owner_key_name])] || [])
    #   end
    # end

    def run
      if !preload_scope || preload_scope.empty_scope?
        all_records = []
        owners.each do |owner|
          owned_records = records_by_owner[owner] || []
          all_records.concat(Array(owned_records)) if owner.jit_preloader || JitPreloader.globally_enabled?
          associate_records_to_owner(owner, owned_records)
        end
        JitPreloader::Preloader.attach(all_records) if all_records.any?
      else
        # Custom preload scope is used and
        # the association can not be marked as loaded
        # Loading into a Hash instead
        records_by_owner
      end
      self
    end

    # Original method:
    # def associate_records_to_owner(owner, records)
    #   association = owner.association(reflection.name)
    #   association.loaded!
    #   if reflection.collection?
    #     association.target.concat(records)
    #   else
    #     association.target = records.first unless records.empty?
    #   end
    # end

    def associate_records_to_owner(owner, records)
      association = owner.association(reflection.name)
      if reflection.collection?
        association.target ||= records
      else
        association.target ||= records.first
      end
    end

    def build_scope
      super.tap do |scope|
        scope.jit_preload! if owners.any?(&:jit_preloader) || JitPreloader.globally_enabled?
      end
    end
  end
end

ActiveRecord::Associations::Preloader::Association.prepend(JitPreloader::PreloaderAssociation)
