# frozen_string_literal: true

# This is a controller
class EmployeesController < ApplicationController
  before_action :authenticate_user
  def index
    @employees = User.where(role: 'employee').page(params[:page]).per(15)
  end

  def approved
    employee = find_employee_by_id
    if employee.update(approved: true)
      create_employee_approved_notification(employee)
      redirect_to employees_path, notice: 'Employee approved successfully.'
    else
      redirect_to employees_path, alert: 'Failed to approve the employee.'
    end
  end

  def reject
    employee = find_employee_by_id
    employee.destroy
    redirect_to employees_path, notice: 'Employee rejected and removed.'
  end

  private

  def find_employee_by_id
    User.find(params[:id])
  end

  def create_employee_approved_notification(employee)
    message = 'Your account has been approved by the admin.'
    Notification.create_employee_approved_notification(employee, message)
  end
end
