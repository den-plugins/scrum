require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class ScrumTest < Test::Unit::TestCase
  
  SCRUM_REQ_FIELDS = {:todo => '', :task_done => ''}
  
  SCRUM_TEST_DATA = {:user_id => 2, :project_id => 1, :todo => 'test todo', :task_done => 'test task done', 
                     :roadblocks => 'test roadblock', :report_on => Date.today}
  
  def test_scrum_create
    scrum = Scrum.new(SCRUM_TEST_DATA)
    assert scrum.save
    scrum.reload
    assert_equal Date.today, scrum.report_on
  end
  
  def test_scrum_create_with_required_fields
    scrum = Scrum.new(SCRUM_TEST_DATA.merge(SCRUM_REQ_FIELDS))
    #todo and task done should not be empty
    assert !scrum.save
  end
  
  def test_scrum_update_with_required_fields
    scrum = Scrum.new(SCRUM_TEST_DATA)
    assert scrum.save
    SCRUM_REQ_FIELDS.each do |key, value|
      scrum.update_attribute(key.to_sym, value)
      assert !scrum.valid?, "Should not be valid. Value of #{key} should not be blank."
    end
  end
  
  def test_get_scrum_for
    assert_nil Scrum.get_scrum_for(1, Date.today, 2)
    
    scrum = Scrum.new(SCRUM_TEST_DATA)
    scrum.save
    
    assert_not_nil Scrum.get_scrum_for(1, Date.today, 2)
  end
  
  def test_scrum_destroy
    scrum = Scrum.new(SCRUM_TEST_DATA)
    assert_difference 'Scrum.count', 1 do
      scrum.save
    end
    
    assert_difference 'Scrum.count', -1 do
      scrum.destroy
    end
  end
  
end