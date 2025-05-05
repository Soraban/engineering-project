"use client"

import React, { useState, useEffect } from 'react';
import { 
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { PlusCircle, Edit, Trash2 } from "lucide-react";
import { toast } from "sonner"


// Type definitions
interface Rule {
  id?: number;
  condition_field: string;
  condition_operator: string;
  condition_value: string;
  category_id: number;
  created_at?: string;
  updated_at?: string;
  priority?: number;
}

interface Category {
  id: number;
  name: string;
  created_at?: string;
  updated_at?: string;
}

const RulesManagement: React.FC = () => {
  // State
  const [rules, setRules] = useState<Rule[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [categoriesLoading, setCategoriesLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [categoriesError, setCategoriesError] = useState<string | null>(null);
  const [open, setOpen] = useState<boolean>(false);
  const [newCategoryMode, setNewCategoryMode] = useState<boolean>(false);
  const [newCategoryName, setNewCategoryName] = useState<string>('');
  const [formData, setFormData] = useState<Rule>({
    condition_field: 'description',
    condition_operator: 'contains',
    condition_value: '',
    category_id: 1
  });

  // Fetch rules and categories on component mount
  useEffect(() => {
    fetchRules();
    fetchCategories();
  }, []);

  const fetchRules = async () => {
    setLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/v1/rules');
      if (!response.ok) {
        throw new Error('Failed to fetch rules');
      }
      const data = await response.json();
      setRules(data);
    } catch (err) {
      setError('Error fetching rules');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    setCategoriesLoading(true);
    try {
      const response = await fetch('http://localhost:8000/api/v1/categories');
      if (!response.ok) {
        throw new Error('Failed to fetch categories');
      }
      const data = await response.json();
      setCategories(data);
      
      // Set default category_id to first category if categories exist
      if (data.length > 0) {
        setFormData(prev => ({
          ...prev,
          category_id: data[0].id
        }));
      }
    } catch (err) {
      setCategoriesError('Error fetching categories');
      console.error(err);
    } finally {
      setCategoriesLoading(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData({
      ...formData,
      [name]: value
    });
  };

  const handleSelectChange = (name: string, value: string) => {
    setFormData({
      ...formData,
      [name]: name === 'category_id' ? parseInt(value) : value
    });
  };

  const createNewCategory = async (): Promise<number | null> => {
    if (!newCategoryName.trim()) {
      toast("Category name cannot be empty");
      return null;
    }
    
    try {
      const response = await fetch('http://localhost:8000/api/v1/categories', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          category: {
            name: newCategoryName.trim()
          }
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to create category');
      }
      
      const newCategory = await response.json();
      toast(`Category "${newCategoryName}" has been created.`);
      
      // Add the new category to our local state
      setCategories([...categories, newCategory]);
      
      // Reset the new category form
      setNewCategoryName('');
      setNewCategoryMode(false);
      
      return newCategory.id;
    } catch (err) {
      toast("Error creating category.");
      console.error(err);
      return null;
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // If we're in new category mode, create the category first
    let categoryId = formData.category_id;
    if (newCategoryMode) {
      const newCatId = await createNewCategory();
      if (!newCatId) return; // Stop if category creation failed
      categoryId = newCatId;
    }
    
    try {
      const response = await fetch('http://localhost:8000/api/v1/rules', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          rule: {
            ...formData,
            category_id: categoryId
          }
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to create rule');
      }
      
      toast("Rule has been created.");
      
      setOpen(false);
      fetchRules();
      setFormData({
        condition_field: 'description',
        condition_operator: 'contains',
        condition_value: '',
        category_id: categories.length > 0 ? categories[0].id : 1
      });
    } catch (err) {
      toast("Error creating Rule.");
      console.error(err);
    }
  };

  if (loading || categoriesLoading) return <div className="flex justify-center p-8">Loading data...</div>;
  if (error) return <div className="text-red-500 p-8">{error}</div>;
  if (categoriesError) return <div className="text-red-500 p-8">{categoriesError}</div>;

  return (
    <div className="container mx-auto p-6">
      <Card className="w-full">
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Transaction Rules</CardTitle>
            <CardDescription>
              Define rules to automatically categorize transactions
            </CardDescription>
          </div>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button className="flex items-center gap-1">
                <PlusCircle size={16} />
                <span>Add Rule</span>
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New Rule</DialogTitle>
                <DialogDescription>
                  Add a new rule to automatically categorize transactions
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={handleSubmit}>
                <div className="grid gap-4 py-4">
                  <div className="grid grid-cols-4 items-center gap-4">
                    <label htmlFor="field" className="text-right">Field</label>
                    <Select
                      name="condition_field"
                      value={formData.condition_field}
                      onValueChange={(value) => handleSelectChange('condition_field', value)}
                    >
                      <SelectTrigger className="col-span-3">
                        <SelectValue placeholder="Select field" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="description">Description</SelectItem>
                        <SelectItem value="amount">Amount</SelectItem>
                        <SelectItem value="payee">Payee</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="grid grid-cols-4 items-center gap-4">
                    <label htmlFor="operator" className="text-right">Operator</label>
                    <Select
                      name="condition_operator"
                      value={formData.condition_operator}
                      onValueChange={(value) => handleSelectChange('condition_operator', value)}
                    >
                      <SelectTrigger className="col-span-3">
                        <SelectValue placeholder="Select operator" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="contains">Contains</SelectItem>
                        <SelectItem value="starts_with">Starts with</SelectItem>
                        <SelectItem value="ends_with">Ends with</SelectItem>
                        <SelectItem value="equals">Equals</SelectItem>
                        <SelectItem value="greater_than">Greater than</SelectItem>
                        <SelectItem value="less_than">Less than</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="grid grid-cols-4 items-center gap-4">
                    <label htmlFor="value" className="text-right">Value</label>
                    <Input
                      id="condition_value"
                      name="condition_value"
                      className="col-span-3"
                      value={formData.condition_value}
                      onChange={handleInputChange}
                      required
                    />
                  </div>
                  <div className="grid grid-cols-4 items-center gap-4">
                    <label htmlFor="category" className="text-right">Category</label>
                    <div className="col-span-3">
                      {newCategoryMode ? (
                        <div className="flex gap-2">
                          <Input
                            id="new_category"
                            name="new_category"
                            value={newCategoryName}
                            onChange={(e) => setNewCategoryName(e.target.value)}
                            placeholder="Enter new category name"
                            className="flex-grow"
                            required
                          />
                          <Button 
                            type="button" 
                            variant="outline" 
                            size="icon"
                            onClick={() => setNewCategoryMode(false)}
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                          </Button>
                        </div>
                      ) : (
                        <Select
                          name="category_id"
                          value={formData.category_id.toString()}
                          onValueChange={(value) => {
                            if (value === "new") {
                              setNewCategoryMode(true);
                            } else {
                              handleSelectChange('category_id', value);
                            }
                          }}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Select category" />
                          </SelectTrigger>
                          <SelectContent>
                            {categories.map((category) => (
                              <SelectItem key={category.id} value={category.id.toString()}>
                                {category.name}
                              </SelectItem>
                            ))}
                            <SelectItem value="new" className="text-primary font-medium">
                              + Create new category
                            </SelectItem>
                          </SelectContent>
                        </Select>
                      )}
                    </div>
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit">Save Rule</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </CardHeader>
        <CardContent>
          <Table>
            <TableCaption>A list of all your transaction rules</TableCaption>
            <TableHeader>
              <TableRow>
                <TableHead>Field</TableHead>
                <TableHead>Operator</TableHead>
                <TableHead>Value</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Created At</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rules.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center">
                    No rules found. Create your first rule!
                  </TableCell>
                </TableRow>
              ) : (
                rules.map((rule) => (
                  <TableRow key={rule.id}>
                    <TableCell>{rule.condition_field}</TableCell>
                    <TableCell>{rule.condition_operator}</TableCell>
                    <TableCell>{rule.condition_value}</TableCell>
                    <TableCell>
                      {categories.find(cat => cat.id === rule.category_id)?.name || rule.category_id}
                    </TableCell>
                    <TableCell>{rule.created_at ? new Date(rule.created_at).toLocaleDateString() : 'N/A'}</TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button variant="outline" size="icon">
                          <Edit size={16} />
                        </Button>
                        <Button variant="outline" size="icon" className="text-red-500">
                          <Trash2 size={16} />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
};

export default RulesManagement;