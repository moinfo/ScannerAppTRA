const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const moment = require('moment');

// In-memory database for sales (would be replaced by a real database in production)
let sales = [
  {
    id: 1,
    customer: 'ABC Company',
    date: '2023-03-15',
    amount: 250000,
    status: 'Completed',
    items: [
      {
        name: 'Website Development',
        quantity: 1,
        price: 250000
      }
    ]
  },
  {
    id: 2,
    customer: 'XYZ Corporation',
    date: '2023-03-10',
    amount: 150000,
    status: 'Pending',
    items: [
      {
        name: 'Logo Design',
        quantity: 1,
        price: 50000
      },
      {
        name: 'Business Cards',
        quantity: 500,
        price: 200
      }
    ]
  },
  {
    id: 3,
    customer: 'Local Shop',
    date: '2023-03-05',
    amount: 75000,
    status: 'Completed',
    items: [
      {
        name: 'Computer Repair',
        quantity: 1,
        price: 75000
      }
    ]
  }
];

// Helper function to filter sales based on query parameters
const filterSales = (query) => {
  let filteredSales = [...sales];
  
  // Apply date range filter
  if (query.start_date && query.end_date) {
    const startDate = moment(query.start_date);
    const endDate = moment(query.end_date).endOf('day');
    
    filteredSales = filteredSales.filter(sale => {
      const saleDate = moment(sale.date);
      return saleDate.isBetween(startDate, endDate, null, '[]');
    });
  }
  
  // Apply search filter
  if (query.search) {
    const searchTerm = query.search.toLowerCase();
    filteredSales = filteredSales.filter(sale => 
      sale.customer.toLowerCase().includes(searchTerm) ||
      sale.id.toString().includes(searchTerm)
    );
  }
  
  return filteredSales;
};

// GET all sales with optional filtering
router.get('/', (req, res) => {
  try {
    const filteredSales = filterSales(req.query);
    
    // Basic pagination
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const startIndex = (page - 1) * limit;
    const endIndex = page * limit;
    
    const paginatedSales = filteredSales.slice(startIndex, endIndex);
    
    res.json({
      success: true,
      data: paginatedSales,
      total: filteredSales.length,
      page,
      limit,
      totalPages: Math.ceil(filteredSales.length / limit)
    });
  } catch (error) {
    console.error('Error getting sales:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sales',
      error: error.message
    });
  }
});

// GET a specific sale by ID
router.get('/:id', (req, res) => {
  try {
    const saleId = parseInt(req.params.id);
    const sale = sales.find(s => s.id === saleId);
    
    if (!sale) {
      return res.status(404).json({
        success: false,
        message: 'Sale not found'
      });
    }
    
    res.json({
      success: true,
      data: sale
    });
  } catch (error) {
    console.error('Error getting sale:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sale',
      error: error.message
    });
  }
});

// POST create a new sale
router.post('/', (req, res) => {
  try {
    const { customer, date, amount, status, items } = req.body;
    
    // Validate required fields
    if (!customer || !date || !amount) {
      return res.status(400).json({
        success: false,
        message: 'Customer, date, and amount are required'
      });
    }
    
    // Generate new ID
    const newId = sales.length > 0 
      ? Math.max(...sales.map(s => s.id)) + 1 
      : 1;
    
    const newSale = {
      id: newId,
      customer,
      date,
      amount: parseFloat(amount),
      status: status || 'Pending',
      items: items || []
    };
    
    sales.push(newSale);
    
    res.status(201).json({
      success: true,
      data: newSale
    });
  } catch (error) {
    console.error('Error creating sale:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create sale',
      error: error.message
    });
  }
});

// PUT update an existing sale
router.put('/:id', (req, res) => {
  try {
    const saleId = parseInt(req.params.id);
    const { customer, date, amount, status, items } = req.body;
    
    const saleIndex = sales.findIndex(s => s.id === saleId);
    
    if (saleIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sale not found'
      });
    }
    
    // Update sale
    const updatedSale = {
      id: saleId,
      customer: customer || sales[saleIndex].customer,
      date: date || sales[saleIndex].date,
      amount: amount ? parseFloat(amount) : sales[saleIndex].amount,
      status: status || sales[saleIndex].status,
      items: items || sales[saleIndex].items
    };
    
    sales[saleIndex] = updatedSale;
    
    res.json({
      success: true,
      data: updatedSale
    });
  } catch (error) {
    console.error('Error updating sale:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update sale',
      error: error.message
    });
  }
});

// DELETE a sale
router.delete('/:id', (req, res) => {
  try {
    const saleId = parseInt(req.params.id);
    const saleIndex = sales.findIndex(s => s.id === saleId);
    
    if (saleIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sale not found'
      });
    }
    
    // Remove sale
    sales.splice(saleIndex, 1);
    
    res.json({
      success: true,
      message: 'Sale deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting sale:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete sale',
      error: error.message
    });
  }
});

// GET sales statistics
router.get('/stats/summary', (req, res) => {
  try {
    const totalSales = sales.reduce((sum, sale) => sum + sale.amount, 0);
    const completedSales = sales.filter(sale => sale.status === 'Completed');
    const pendingSales = sales.filter(sale => sale.status === 'Pending');
    
    const totalCompleted = completedSales.reduce((sum, sale) => sum + sale.amount, 0);
    const totalPending = pendingSales.reduce((sum, sale) => sum + sale.amount, 0);
    
    // Group by month
    const salesByMonth = {};
    sales.forEach(sale => {
      const month = moment(sale.date).format('YYYY-MM');
      if (!salesByMonth[month]) {
        salesByMonth[month] = 0;
      }
      salesByMonth[month] += sale.amount;
    });
    
    res.json({
      success: true,
      data: {
        totalSales,
        totalCompleted,
        totalPending,
        completedCount: completedSales.length,
        pendingCount: pendingSales.length,
        salesByMonth
      }
    });
  } catch (error) {
    console.error('Error getting sales statistics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sales statistics',
      error: error.message
    });
  }
});

// POST create a sale from receipt
router.post('/from-receipt/:receiptId', (req, res) => {
  try {
    const receiptId = req.params.receiptId;
    
    // In production, you would fetch the receipt from your database
    // Here we'll simulate creating a sale from receipt data
    
    const { companyName, totalAmount, date } = req.body;
    
    if (!companyName || !totalAmount || !date) {
      return res.status(400).json({
        success: false,
        message: 'Company name, total amount, and date are required'
      });
    }
    
    // Generate new ID
    const newId = sales.length > 0 
      ? Math.max(...sales.map(s => s.id)) + 1 
      : 1;
    
    const newSale = {
      id: newId,
      customer: companyName,
      date: date,
      amount: parseFloat(totalAmount),
      status: 'Completed',
      items: [
        {
          name: 'From Receipt',
          quantity: 1,
          price: parseFloat(totalAmount)
        }
      ],
      receiptId: receiptId
    };
    
    sales.push(newSale);
    
    res.status(201).json({
      success: true,
      data: newSale
    });
  } catch (error) {
    console.error('Error creating sale from receipt:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create sale from receipt',
      error: error.message
    });
  }
});

module.exports = router;