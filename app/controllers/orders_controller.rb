# frozen_string_literal: true

# This is a controller
# rubocop:disable Metrics/ClassLength
class OrdersController < ApplicationController
  include OrdersHelper

  before_action :authenticate_user

  # rubocop:disable Metrics/AbcSize
  def index
    @food_menus = if params[:search].present?
                    FoodMenu.search(params[:search]).records.includes(:food_store).page(params[:page]).per(10)
                  else
                    FoodMenu.includes(:food_store).page(params[:page]).per(10)
                  end

    @order = current_order || Order.new
    @food_stores = FoodStore.all
    @food_categories = FoodCategory.all

    calculate_distances_for_employee if current_user.role == 'employee' && current_user.company_id.present?
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def place_order
    items = params[:items]

    if items.empty?
      render json: { error: 'Cart is empty.' }, status: :unprocessable_entity
      return
    end

    order = current_user.orders.new

    food_item_names = []
    quantities = []
    food_store_names = []
    prices = []
    special_ingredients = []

    items.each do |item|
      food_item_names << item['food_item_name']
      quantities << item['quantity']
      food_store_names << item['food_store_name']
      prices << (item['quantity'] * item['price']).round(2)
      special_ingredients << item['special_ingredients']
    end

    order.food_item_names = food_item_names
    order.quantities = quantities
    order.food_store_names = food_store_names
    order.prices = prices
    order.special_ingredients = special_ingredients

    if current_user.company_id.present?
      company = Company.find_by(id: current_user.company_id)
      order.company_name = company&.name
    else
      order.company_name = 'Other'
    end

    if order.save
      order.update(status: 'placed')
      render json: { message: 'Order placed successfully!' }, status: 200
      OrderMailer.confirmation_email(order).deliver_now
    else
      render json: { error: 'Failed to place order.' }, status: :unprocessable_entity
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def confirm_order
    @order = Order.find(params[:order_id])
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def search
    @food_menus = FoodMenu.includes(:food_store)

    if params[:search].present?
      search_results = FoodMenu.search(params[:search]).records.includes(:food_store)
      @food_menus = @food_menus.merge(search_results)
    end

    if params[:food_store_filter].present?
      food_store_id = params[:food_store_filter].to_i
      @food_menus = @food_menus.where(food_store_id: food_store_id)
    end

    if params[:food_category_filter].present?
      food_category_id = params[:food_category_filter].to_i
      @food_menus = @food_menus.where(food_category_id: food_category_id)
    end

    @food_stores = FoodStore.all
    @food_categories = FoodCategory.all

    @distances = calculate_distances(@food_stores)

    render partial: 'search_results'
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def order_history
    @orders = current_user.orders.order(created_at: :desc)
    render 'order_history'
  end

  def order_status
    @orders = Order.all.sort_by { |order| order.company_name.present? ? 0 : 1 }
    render 'order_status'
  end

  private

  def current_order
    @current_order ||= find_order_by_session
  end

  def find_order_by_session
    Order.find_by(id: session[:order_id]) if session[:order_id]
  end

  def calculate_total_price(food_menus)
    food_menus.sum { |food_menu| food_menu[:price] }
  end

  def save_cart_items(cart_items)
    cart_items_json = cart_items.to_json
    localStorage.setItem('cartItems', cart_items_json)
  end

  def clear_cart_items
    localStorage.removeItem('cartItems')
  end

  def calculate_distances_for_employee
    if current_user.company_id.zero?
      [22.33, 77.33] # Use default values if company_id is not set
    else
      company = Company.find_by(id: current_user.company_id)
      [company&.latitude, company&.longitude] # Use company latitude and longitude if available
    end

    @distances = calculate_distances(@food_stores).map do |food_store, distance|
      [food_store, distance.round(2)]
    end
  end
end
# rubocop:enable Metrics/ClassLength
