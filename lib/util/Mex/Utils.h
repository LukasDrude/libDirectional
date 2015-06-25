
/* >> This file is part of the Nonlinear Estimation Toolbox
 *
 *    For more information, see https://bitbucket.org/NonlinearEstimation/toolbox
 *
 *    Copyright (C) 2015  Jannik Steinbring <jannik.steinbring@kit.edu>
 *                        Antonio Zea <antonio.zea@kit.edu>  
 *
 *                        Institute for Anthropomatics and Robotics
 *                        Chair for Intelligent Sensor-Actuator-Systems (ISAS)
 *                        Karlsruhe Institute of Technology (KIT), Germany
 *
 *                        http://isas.uka.de
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _MEX_UTILS_H_
#define _MEX_UTILS_H_

#include "../../external/Eigen/Dense"
#include <stdexcept>

namespace Mex {

struct Utils {
    static Eigen::VectorXi getDimensions(const mxArray* array) {
        mxAssert(!mxIsSparse(array), "Array must be dense.");
        
        unsigned int numDims = mxGetNumberOfDimensions(array);
        Eigen::VectorXi outDims(numDims);
        
        const mwSize* dims = mxGetDimensions(array);
        std::copy(dims, dims + numDims, outDims.data());
        
        return outDims;
    }
    
    // from the slice size vectors [..., i, ...] and [..., j, ...]
    // creates the slice size vector [..., max(i, j), ...], taking 
    // into account that the inputs might have different sizes
    static Eigen::VectorXi expandSliceDims(const Eigen::VectorXi& sliceDimsA,
                                           const Eigen::VectorXi& sliceDimsB) {
        Eigen::VectorXi sliceDims(std::max(sliceDimsA.size(), sliceDimsB.size()));
        
        for (int i = 0; i < sliceDims.size(); i++) {
            sliceDims(i) = std::max(i < sliceDimsA.size() ? sliceDimsA(i) : 1, 
                                    i < sliceDimsB.size() ? sliceDimsB(i) : 1);
        }
        
        return sliceDims;
    }
    
    template<class MatA, class MatB>
    static Eigen::VectorXi expandSlices(const MatA& matA,
                                        const MatB& matB) {
        return expandSliceDims(matA.slices(), matB.slices());
    }
    
    static Eigen::VectorXi expandSlices(const Eigen::VectorXi& dimsA, 
                                        const Eigen::VectorXi& dimsB) {
        return expandSliceDims(dimsA.tail(dimsA.size() - 2),
                               dimsB.tail(dimsB.size() - 2));
    }
    
    // checks if sliceMins <= slice <= sliceMax coefficient wise,
    // taking into account that the inputs might have different sizes
    static bool isValidSlice(const Eigen::VectorXi& slice, 
                             const Eigen::VectorXi& sliceMins,
                             const Eigen::VectorXi& sliceMaxs) {
        const Eigen::VectorXi::Index sliceDims = sliceMins.size();
        const Eigen::VectorXi sHead = slice.head(sliceDims);
        const Eigen::VectorXi sTail = slice.tail(slice.size() - sliceDims);
        
        if (slice.size() < sliceDims) {
            return false;
        } else if (sHead.size() == 0) {
            return sTail.isZero();
        } else {
            return sliceMins.cwiseMin(sHead) == sliceMins &&
                   sliceMaxs.cwiseMax(sHead) == sliceMaxs &&
                   (slice.size() == sliceDims || sTail.isZero());
        }
    }
    
    template<typename Scalar>
    static Scalar* checkArrayType(mxArray* array) {
        if (!Traits<Scalar>::isValidArray(array)) {
            throw std::invalid_argument("MX array of invalid type.");
        }
        
        return (Scalar*) mxGetData(array);
    }
    
    template<typename Scalar>
    static const Scalar* checkArrayType(const mxArray* array) {
        if (!Traits<Scalar>::isValidArray(array)) {
            throw std::invalid_argument("MX array of invalid type.");
        }
        
        return (const Scalar*) mxGetData(array);
    }
    
    template<int r>
    static int checkRows(int rows) {
        if (r == Eigen::Dynamic || r == rows) {
            return rows;
        } else {
            throw std::invalid_argument("Mismatch between given (" +
                                        std::to_string(rows) +
                                        ") and expected (" +
                                        std::to_string(r) +
                                        ") number of rows.");
        }
    }
    
    template<int r>
    static int checkRows(const mxArray* array) {
        return checkRows<r>(mxGetM(array));
    }
    
    template<int c>
    static int checkCols(int cols) {
        if (c == Eigen::Dynamic || c == cols) {
            return cols;
        } else {
            throw std::invalid_argument("Mismatch between given (" +
                                        std::to_string(cols) +
                                        ") and expected (" +
                                        std::to_string(c) +
                                        ") number of columns.");
        }
    }
    
    template<int c>
    static int checkCols(const mxArray* array) {
        return checkCols<c>(mxGetN(array));
    }
    
};

}   // namespace Mex

#endif
